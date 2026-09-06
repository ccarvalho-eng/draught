defmodule Draught.Provider.OpenAITest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Provider
  alias Draught.Provider.OpenAI
  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.Request

  defmodule StubTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    alias Draught.Provider.OpenAI.Transport.Response

    @impl Draught.Provider.OpenAI.Transport
    def complete(request, script) do
      case next(script, request) do
        {:response, status, body} -> {:ok, %Response{status: status, body: body}}
        {:error, failure} -> {:error, failure}
      end
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(request, script, initial, reducer) do
      case next(script, request) do
        {:response, status, chunks} ->
          {state, _output} = reduce(chunks, initial, reducer)
          {:ok, %Response{status: status}, state}

        {:disconnect, chunks, failure} ->
          {_state, output} = reduce(chunks, initial, reducer)
          {:error, failure, output}
      end
    end

    defp next(script, request) do
      Agent.get_and_update(script, fn state ->
        [response | rest] = state.responses
        {response, %{state | responses: rest, requests: [request | state.requests]}}
      end)
    end

    defp reduce(chunks, initial, reducer) do
      Enum.reduce_while(chunks, {initial, false}, fn chunk, {state, output} ->
        case reducer.(chunk, state) do
          {:cont, updated, emitted} -> {:cont, {updated, output or emitted}}
          {:halt, updated, emitted} -> {:halt, {updated, output or emitted}}
        end
      end)
    end
  end

  test "constructs an adapter and reports configuration-sensitive capabilities" do
    assert {:ok, adapter} = OpenAI.new()
    assert {:ok, capabilities} = Provider.capabilities(adapter)
    assert capabilities.chat
    assert capabilities.streaming
    assert capabilities.tool_calls
    assert capabilities.usage
    refute capabilities.reasoning

    assert {:ok, adapter} = OpenAI.new(reasoning_field: :reasoning_content)
    assert {:ok, capabilities} = Provider.capabilities(adapter)
    assert capabilities.reasoning

    assert {:error, %Normalized{kind: :configuration}} =
             Provider.complete({OpenAI, :invalid}, request())
  end

  test "completes a request and retries only transient failures" do
    script =
      start_script([
        {:response, 503, nil},
        {:error, Failure.new(:closed)},
        {:response, 200, complete_body("Done")}
      ])

    assert {:ok, adapter} = adapter(script, max_attempts: 3)
    assert {:ok, response} = Provider.complete(adapter, request())
    [content] = response.message.content
    assert content.text == "Done"
    assert request_count(script) == 3

    [transport_request | _rest] = requests(script)
    assert transport_request.body["model"] == "test-model"
    assert transport_request.url == "https://api.openai.com/v1/chat/completions"
  end

  test "does not retry non-transient HTTP statuses" do
    script =
      start_script([
        {:response, 401, nil},
        {:response, 200, complete_body("unexpected")}
      ])

    assert {:ok, adapter} = adapter(script, max_attempts: 3)

    assert {:error, %Normalized{code: "http_401", retryable: false}} =
             Provider.complete(adapter, request())

    assert request_count(script) == 1
  end

  test "bounds attempts when transient failures continue" do
    script =
      start_script([
        {:response, 429, nil},
        {:response, 503, nil},
        {:response, 504, nil}
      ])

    assert {:ok, adapter} = adapter(script, max_attempts: 3)

    assert {:error, %Normalized{code: "http_504", retryable: true}} =
             Provider.complete(adapter, request())

    assert request_count(script) == 3
  end

  test "streams canonical events and returns one completed terminal event" do
    chunks = [
      sse(%{"role" => "assistant", "content" => "Hel"}),
      sse(%{"content" => "lo"}, "stop", usage()),
      done()
    ]

    script = start_script([{:response, 200, chunks}])
    assert {:ok, adapter} = adapter(script)
    parent = self()

    assert {:ok, response} =
             Provider.stream(adapter, request(), fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert response.usage.total_tokens == 7
    assert_receive {:event, %Delta{kind: :text, content: "Hel"}}
    assert_receive {:event, %Delta{kind: :text, content: "lo"}}
    assert_receive {:event, %Completed{response: ^response}}
    refute_receive {:event, _event}
  end

  test "retries a disconnected stream before canonical output" do
    role_only = sse(%{"role" => "assistant", "content" => ""})
    success = [sse(%{"content" => "Done"}, "stop"), done()]

    script =
      start_script([
        {:disconnect, [role_only], Failure.new(:closed)},
        {:response, 200, success}
      ])

    assert {:ok, adapter} = adapter(script, max_attempts: 2)
    parent = self()

    assert {:ok, _response} =
             Provider.stream(adapter, request(), fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert request_count(script) == 2
    assert_receive {:event, %Delta{content: "Done"}}
    assert_receive {:event, %Completed{}}
    refute_receive {:event, _event}
  end

  test "never retries a disconnected stream after canonical output" do
    script =
      start_script([
        {:disconnect, [sse(%{"content" => "visible"})], Failure.new(:closed)},
        {:response, 200, [sse(%{"content" => "duplicate"}, "stop"), done()]}
      ])

    assert {:ok, adapter} = adapter(script, max_attempts: 2)
    parent = self()

    assert {:error, %Normalized{code: "connection_closed"} = error} =
             Provider.stream(adapter, request(), fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert request_count(script) == 1
    assert_receive {:event, %Delta{content: "visible"}}
    assert_receive {:event, %Failed{error: ^error}}
    refute_receive {:event, _event}
  end

  test "rejects an incomplete SSE stream without retrying" do
    script = start_script([{:response, 200, [sse(%{"content" => "partial"})]}])
    assert {:ok, adapter} = adapter(script, max_attempts: 3)

    assert {:error, %Normalized{code: "incomplete_stream", retryable: false}} =
             Provider.stream(adapter, request(), fn _event -> :ok end)

    assert request_count(script) == 1
  end

  test "propagates synchronous consumer cancellation without another attempt" do
    chunks = [sse(%{"content" => "first"}), sse(%{"content" => "second"}, "stop"), done()]
    script = start_script([{:response, 200, chunks}])
    assert {:ok, adapter} = adapter(script, max_attempts: 3)

    assert {:error, %Normalized{kind: :cancellation}} =
             Provider.stream(adapter, request(), fn _event -> :halt end)

    assert request_count(script) == 1
  end

  defp adapter(script, options \\ []) do
    retry = %{max_attempts: Keyword.get(options, :max_attempts, 1), fixed_delay_ms: 0}
    OpenAI.new([retry: retry], {StubTransport, script})
  end

  defp request do
    assert {:ok, user} = Conversation.user("Hello")
    assert {:ok, request} = Request.new(model: "test-model", messages: [user])
    request
  end

  defp start_script(responses) do
    start_supervised!({Agent, fn -> %{responses: responses, requests: []} end})
  end

  defp request_count(script) do
    Agent.get(script, fn state -> length(state.requests) end)
  end

  defp requests(script) do
    Agent.get(script, fn state -> state.requests end)
  end

  defp complete_body(content) do
    Jason.encode!(%{
      "choices" => [
        %{
          "index" => 0,
          "message" => %{"role" => "assistant", "content" => content},
          "finish_reason" => "stop"
        }
      ]
    })
  end

  defp sse(delta, finish_reason \\ nil, usage \\ nil) do
    payload = %{
      "choices" => [%{"index" => 0, "delta" => delta, "finish_reason" => finish_reason}],
      "usage" => usage
    }

    "data: " <> Jason.encode!(payload) <> "\n\n"
  end

  defp done do
    "data: [DONE]\n\n"
  end

  defp usage do
    %{"prompt_tokens" => 4, "completion_tokens" => 3, "total_tokens" => 7}
  end
end
