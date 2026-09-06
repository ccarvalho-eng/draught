defmodule Draught.Provider.FakeTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider
  alias Draught.Provider.Fake
  alias Draught.Provider.Fake.Completion
  alias Draught.Provider.Fake.Stream
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Tool.Call
  alias Draught.Validation.Error

  test "completes exact text, tool, usage, and error routes" do
    text_request = request("text")
    tool_request = request("tool")
    error_request = request("error")
    text_response = text_response()
    tool_response = tool_response()
    error = transport_error()

    assert {:ok, fake} =
             Fake.new(
               completions: [
                 %{request: text_request, response: text_response},
                 %{request: tool_request, response: tool_response},
                 %{request: error_request, error: error}
               ]
             )

    adapter = {Fake, fake}
    assert {:ok, capabilities} = Provider.capabilities(adapter)
    assert capabilities.chat
    assert {:ok, ^text_response} = Provider.complete(adapter, text_request)
    assert {:ok, ^tool_response} = Provider.complete(adapter, tool_request)
    assert {:error, ^error} = Provider.complete(adapter, error_request)
  end

  test "emits stream events in order and returns the terminal response" do
    request = request("stream")
    response = text_response()

    assert {:ok, first} = Delta.new(kind: :text, content: "hel")
    assert {:ok, second} = Delta.new(kind: :text, content: "lo")

    assert {:ok, fake} =
             Fake.new(
               streams: [
                 %{request: request, events: [first, second], response: response}
               ]
             )

    adapter = {Fake, fake}
    parent = self()

    assert {:ok, ^response} =
             Provider.stream(adapter, request, fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert_receive {:event, received_first}
    assert_receive {:event, received_second}
    assert_receive {:event, %Completed{response: ^response} = received_terminal}

    assert [received_first, received_second, received_terminal] == [
             first,
             second,
             %Completed{response: response}
           ]
  end

  test "streams tool calls and failures as typed terminal sequences" do
    tool_request = request("tool stream")
    failed_request = request("failed stream")
    response = tool_response()
    error = transport_error()
    call = hd(response.message.tool_calls)

    assert {:ok, tool_call} = ToolCall.new(call: call)

    assert {:ok, fake} =
             Fake.new(
               streams: [
                 %{request: tool_request, events: [tool_call], response: response},
                 %{request: failed_request, events: [], error: error}
               ]
             )

    parent = self()

    assert {:ok, ^response} =
             Provider.stream({Fake, fake}, tool_request, fn event ->
               send(parent, {:tool_stream, event})
               :ok
             end)

    assert_receive {:tool_stream, ^tool_call}
    assert_receive {:tool_stream, %Completed{response: ^response}}

    assert {:error, ^error} =
             Provider.stream({Fake, fake}, failed_request, fn event ->
               send(parent, {:failed_stream, event})
               :ok
             end)

    assert_receive {:failed_stream, %Failed{error: ^error}}
  end

  test "returns a canonical error for exact-route misses" do
    assert {:ok, fake} = Fake.new()

    assert {:error, %Normalized{kind: :configuration, code: "fake_route_not_found"}} =
             Provider.complete({Fake, fake}, request("missing"))

    assert {:error, %Normalized{kind: :configuration, code: "fake_route_not_found"}} =
             Provider.stream({Fake, fake}, request("missing"), fn _event -> :ok end)
  end

  test "turns a sink halt into explicit cancellation" do
    request = request("cancel")
    response = text_response()
    assert {:ok, delta} = Delta.new(kind: :text, content: "partial")

    assert {:ok, fake} =
             Fake.new(
               streams: [
                 %{request: request, events: [delta], response: response}
               ]
             )

    assert {:error, %Normalized{kind: :cancellation, code: "stream_cancelled"}} =
             Provider.stream({Fake, fake}, request, fn _event -> :halt end)
  end

  test "rejects duplicate routes and adapter-owned terminal events" do
    request = request("duplicate")
    response = text_response()
    route = %{request: request, response: response}

    assert {:error, %Error{}} = Fake.new(completions: [route, route])

    assert {:ok, completed} = Completed.new(response: response)

    assert {:error, %Error{}} =
             Fake.new(
               streams: [
                 %{request: request, events: [completed], response: response}
               ]
             )
  end

  test "revalidates route structs and rejects malformed route collections" do
    request = request("route")
    response = text_response()
    assert {:ok, completion} = Completion.new(request: request, response: response)

    assert {:ok, stream} =
             Stream.new(request: request, events: [], response: response)

    assert {:ok, fake} = Fake.new(completions: [completion], streams: [stream])
    assert fake.completions == [completion]
    assert fake.streams == [stream]
    assert {:error, %Error{}} = Fake.new(completions: :invalid)
    assert {:error, %Error{}} = Fake.new(streams: :invalid)
  end

  test "accepts external route values and rejects malformed route relationships" do
    request_attributes = %{
      model: "fake-model",
      messages: [%{role: :user, content: "external"}]
    }

    response_attributes = %{
      message: %{content: "external response"},
      finish_reason: :stop
    }

    delta_attributes = %{
      type: :delta,
      kind: :text,
      content: "external"
    }

    assert {:ok, completion} =
             Completion.new(request: request_attributes, response: response_attributes)

    assert {:ok, stream} =
             Stream.new(
               request: request_attributes,
               events: [delta_attributes],
               response: response_attributes
             )

    assert completion.request == stream.request
    assert {:error, %Error{}} = Completion.new(request: request_attributes)

    assert {:error, %Error{}} =
             Completion.new(
               request: request_attributes,
               response: response_attributes,
               error: transport_error()
             )

    assert {:ok, %Stream{events: []}} =
             Stream.new(
               request: request_attributes,
               events: [],
               response: response_attributes
             )

    assert {:error, %Error{}} = Stream.new(request: request_attributes, events: :invalid)

    assert {:error, %Error{}} =
             Stream.new(
               request: request_attributes,
               events: [%{type: :delta, kind: :text, content: ""}],
               response: response_attributes
             )
  end

  test "validates explicit capabilities and malformed route structs" do
    assert {:ok, fake} = Fake.new(capabilities: %{chat: false, streaming: false})
    refute fake.capabilities.chat
    refute fake.capabilities.streaming

    request = request("invalid structs")
    invalid_response = %Response{message: :invalid, finish_reason: :stop}

    assert {:error, %Error{}} =
             Completion.new(request: request, response: invalid_response)

    invalid_error = %Normalized{
      kind: :unknown,
      code: "bad",
      message: "bad",
      retryable: false
    }

    assert {:error, %Error{}} = Completion.new(request: request, error: invalid_error)
  end

  test "normalizes external values in explicit route results without raising" do
    request = request("external result")

    response = %{
      message: %{content: "external response"},
      finish_reason: :stop
    }

    error = %{
      kind: :transport,
      code: "offline",
      message: "provider is offline",
      retryable: true
    }

    assert {:ok, %Completion{result: {:ok, %Response{}}}} =
             Completion.new(request: request, result: {:ok, response})

    assert {:ok, %Completion{result: {:error, %Normalized{}}}} =
             Completion.new(request: request, result: {:error, error})

    assert {:error, %Error{}} = Completion.new(request: request, result: {:ok, :invalid})
    assert {:error, %Error{}} = Completion.new(request: request, result: {:error, :invalid})
  end

  defp request(content) do
    assert {:ok, user} = Conversation.user(content)
    assert {:ok, request} = Request.new(model: "fake-model", messages: [user])
    request
  end

  defp text_response do
    assert {:ok, assistant} = Conversation.assistant(content: "hello")

    assert {:ok, usage} =
             Usage.new(input_tokens: 2, output_tokens: 1, cached_tokens: 1)

    assert {:ok, response} =
             Response.new(message: assistant, finish_reason: :stop, usage: usage)

    response
  end

  defp tool_response do
    assert {:ok, call} = Call.new(id: "call-1", name: "read_file", arguments: %{})
    assert {:ok, assistant} = Conversation.assistant(tool_calls: [call])
    assert {:ok, response} = Response.new(message: assistant, finish_reason: :tool_calls)
    response
  end

  defp transport_error do
    assert {:ok, error} =
             Normalized.new(:transport, "connection_closed", "connection closed", retryable: true)

    error
  end
end
