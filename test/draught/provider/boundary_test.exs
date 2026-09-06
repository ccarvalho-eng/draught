defmodule Draught.Provider.BoundaryTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Conversation.Message.Assistant
  alias Draught.Error.Normalized
  alias Draught.Event
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Provider
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Call
  alias Draught.Tool.Specification
  alias Draught.Validation.Error

  defmodule InvalidResultProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_config) do
      :invalid
    end

    @impl Draught.Provider
    def complete(_request, :raw) do
      :invalid
    end

    def complete(_request, _config) do
      {:ok, %Draught.Provider.Response{message: :invalid, finish_reason: :stop}}
    end

    @impl Draught.Provider
    def stream(_request, config, sink) do
      sink.(%Draught.Event.Provider.Delta{kind: :text, content: ""})
      {:ok, config}
    end
  end

  defmodule ErrorProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(config) do
      {:error, config}
    end

    @impl Draught.Provider
    def complete(_request, config) do
      {:error, config}
    end

    @impl Draught.Provider
    def stream(_request, config, _sink) do
      {:error, config}
    end
  end

  defmodule StreamProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_config) do
      :unused
    end

    @impl Draught.Provider
    def complete(_request, _config) do
      :unused
    end

    @impl Draught.Provider
    def stream(_request, config, sink) do
      Enum.each(config.events, sink)
      send(config.parent, :adapter_finished)
      config.result
    end
  end

  describe "events" do
    test "constructs and identifies every event variant" do
      response = response()
      assert {:ok, error} = Normalized.new(:transport, "closed", "connection closed")
      assert {:ok, call} = Call.new(id: "call-1", name: "read_file")

      values = [
        {:delta, Event.new(type: :delta, kind: :text, content: "hello")},
        {:tool_call, Event.new(type: :tool_call, call: call)},
        {:completed, Event.new(type: :completed, response: response)},
        {:failed, Event.new(type: :failed, error: error)}
      ]

      Enum.each(values, fn {type, result} ->
        assert {:ok, event} = result
        assert Event.type(event) == type
        assert {:ok, ^event} = Event.validate(event)
      end)
    end

    test "rejects unsupported, empty, and malformed events" do
      assert {:error, %Error{}} = Event.new(type: :unknown)
      assert {:error, %Error{}} = Event.new(type: :delta, kind: :text, content: "")
      assert {:error, %Error{}} = Event.validate(%Delta{kind: :text, content: ""})
      assert {:error, %Error{}} = Event.validate(:not_an_event)
    end
  end

  describe "provider boundary" do
    test "rejects missing adapters and malformed callback results" do
      request = request()

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.complete({String, nil}, request)

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.complete(:invalid, request)

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.capabilities({InvalidResultProvider, nil})

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.complete({InvalidResultProvider, nil}, request)

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.complete({InvalidResultProvider, :raw}, request)

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.stream({InvalidResultProvider, response()}, request, fn _event ->
                 :ok
               end)
    end

    test "rejects invalid requests and sinks as configuration errors" do
      request = request()

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.complete({ErrorProvider, runtime_error()}, %{model: "missing messages"})

      invalid = %{request | model: ""}

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.complete({ErrorProvider, runtime_error()}, invalid)

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.stream({ErrorProvider, runtime_error()}, request, :not_a_function)
    end

    test "passes canonical provider failures through after validation" do
      error = runtime_error()

      assert {:error, ^error} = Provider.capabilities({ErrorProvider, error})
      assert {:error, ^error} = Provider.complete({ErrorProvider, error}, request())

      assert {:error, ^error} =
               Provider.stream({ErrorProvider, error}, request(), fn _event -> :ok end)
    end

    test "rejects malformed provider errors and invalid sink results" do
      malformed = %Normalized{
        kind: :unknown,
        code: "bad",
        message: "bad",
        retryable: false
      }

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.capabilities({ErrorProvider, malformed})

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.capabilities({ErrorProvider, :not_an_error})

      request = request()
      response = response()
      assert {:ok, delta} = Delta.new(kind: :text, content: "hello")
      config = %{events: [delta], parent: self(), result: {:ok, response}}

      assert {:error, %Normalized{kind: :configuration}} =
               Provider.stream({StreamProvider, config}, request, fn _event -> :invalid end)

      refute_received :adapter_finished
    end

    test "owns exactly one terminal event for adapter success and failure" do
      request = request()
      response = response()
      error = runtime_error()
      parent = self()
      success = %{events: [], parent: parent, result: {:ok, response}}

      assert {:ok, ^response} =
               Provider.stream({StreamProvider, success}, request, fn event ->
                 send(parent, {:success_event, event})
                 :ok
               end)

      assert_receive :adapter_finished
      assert_receive {:success_event, %Completed{response: ^response}}
      refute_receive {:success_event, _event}

      failure = %{events: [], parent: parent, result: {:error, error}}

      assert {:error, ^error} =
               Provider.stream({StreamProvider, failure}, request, fn event ->
                 send(parent, {:failure_event, event})
                 :ok
               end)

      assert_receive :adapter_finished
      assert_receive {:failure_event, %Failed{error: ^error}}
      refute_receive {:failure_event, _event}
    end

    test "rejects adapter terminal events and aborts emission when the sink halts" do
      request = request()
      response = response()
      parent = self()
      terminal = completed(response)
      terminal_config = %{events: [terminal], parent: parent, result: {:ok, response}}

      assert {:error, %Normalized{kind: :protocol}} =
               Provider.stream({StreamProvider, terminal_config}, request, fn _event -> :ok end)

      refute_received :adapter_finished

      assert {:ok, first} = Delta.new(kind: :text, content: "first")
      assert {:ok, second} = Delta.new(kind: :text, content: "second")
      halt_config = %{events: [first, second], parent: parent, result: {:ok, response}}

      assert {:error, %Normalized{kind: :cancellation}} =
               Provider.stream({StreamProvider, halt_config}, request, fn event ->
                 send(parent, {:halt_event, event})
                 :halt
               end)

      assert_receive {:halt_event, ^first}
      refute_receive {:halt_event, ^second}
      refute_received :adapter_finished
    end
  end

  defp request do
    assert {:ok, request} =
             Request.new(
               model: "model",
               messages: [user()],
               tools: [tool_specification()],
               options: %{temperature: 0}
             )

    request
  end

  defp user do
    assert {:ok, user} = Conversation.user("Hello")
    user
  end

  defp tool_specification do
    assert {:ok, tool} =
             Specification.new(
               name: "read_file",
               description: "Read a file",
               input_schema: %{"type" => "object"}
             )

    tool
  end

  defp response do
    assert {:ok, message} = Conversation.assistant(content: "Hello")
    assert %Assistant{} = message
    assert {:ok, response} = Response.new(message: message, finish_reason: :stop)
    response
  end

  defp runtime_error do
    assert {:ok, error} = Normalized.new(:transport, "failed", "provider failed")
    error
  end

  defp completed(response) do
    assert {:ok, event} = Completed.new(response: response)
    event
  end
end
