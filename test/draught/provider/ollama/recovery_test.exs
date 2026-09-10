defmodule Draught.Provider.Ollama.RecoveryTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama
  alias Draught.Provider.Ollama.Runtime
  alias Draught.Provider.OpenAI
  alias Draught.Provider.OpenAI.Transport.Response
  alias Draught.Provider.Request
  alias Draught.Tool.Specification

  defmodule ScriptedTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    @impl Draught.Provider.OpenAI.Transport
    def complete(_request, script) do
      {:ok, %Response{status: 200, body: next(script)}}
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(_request, script, initial, reducer) do
      final =
        script
        |> next()
        |> Enum.reduce_while(initial, fn chunk, state ->
          case reducer.(chunk, state) do
            {:cont, updated, _output?} -> {:cont, updated}
            {:halt, updated, _output?} -> {:halt, updated}
          end
        end)

      {:ok, %Response{status: 200}, final}
    end

    defp next(script) do
      Agent.get_and_update(script, fn %{responses: [response | rest]} = state ->
        {response, %{state | requests: state.requests + 1, responses: rest}}
      end)
    end
  end

  test "retries a leaked textual tool call before publishing stream events" do
    script = start_script([malformed_stream(), text_stream("Version found")])
    parent = self()
    provider = adapter(script)
    provider_request = request()

    assert {:ok, response} =
             Provider.stream(provider, provider_request, fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert requests(script) == 2

    assert [%Draught.Conversation.Content.Text{text: "Version found"}] =
             response.message.content

    assert_receive {:event, %Delta{kind: :text, content: "Version found"}}
    assert_receive {:event, %Completed{response: ^response}}
    refute_receive {:event, _event}
  end

  test "returns a recoverable failure when both streamed attempts leak tool markup" do
    script = start_script([malformed_stream(""), malformed_stream("")])
    parent = self()
    provider = adapter(script)
    provider_request = request()

    assert {:error,
            %Normalized{
              code: "ollama_malformed_tool_call",
              kind: :protocol,
              retryable: true
            } = error} =
             Provider.stream(provider, provider_request, fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert requests(script) == 2
    assert_receive {:event, %Failed{error: ^error}}
    refute_receive {:event, _event}
  end

  test "retries malformed complete responses and preserves canonical tool calls" do
    script = start_script([malformed_completion(), tool_completion()])
    provider = adapter(script)
    provider_request = request()

    assert {:ok, response} = Provider.complete(provider, provider_request)
    assert requests(script) == 2

    assert [%Draught.Tool.Call{name: "read_file", arguments: %{"path" => "mix.exs"}}] =
             response.message.tool_calls
  end

  test "replays validated streamed tool calls after buffering" do
    script = start_script([tool_stream()])
    parent = self()
    provider = adapter(script)
    provider_request = request()

    assert {:ok, response} =
             Provider.stream(provider, provider_request, fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert_receive {:event, %ToolCall{call: call}}
    assert call.name == "read_file"
    assert call.arguments == %{"path" => "mix.exs"}
    assert_receive {:event, %Completed{response: ^response}}
    refute_receive {:event, _event}
  end

  test "does not retry ordinary text that contains an incomplete markup example" do
    content = "The parser recognizes <function=name> as an opening tag."
    script = start_script([text_stream(content)])
    provider = adapter(script)
    provider_request = request()

    assert {:ok, response} = Provider.stream(provider, provider_request, fn _event -> :ok end)
    assert requests(script) == 1
    assert [%Draught.Conversation.Content.Text{text: ^content}] = response.message.content
  end

  test "does not inspect textual responses when the request exposes no tools" do
    script = start_script([malformed_stream()])
    provider = adapter(script)
    provider_request = request_without_tools()

    assert {:ok, response} =
             Provider.stream(provider, provider_request, fn _event -> :ok end)

    assert requests(script) == 1
    assert response.finish_reason == :stop
  end

  test "does not retry after a consumer cancels buffered delivery" do
    script = start_script([text_stream("Stop here"), text_stream("unexpected")])
    provider = adapter(script)
    provider_request = request()

    assert {:error, %Normalized{kind: :cancellation}} =
             Provider.stream(provider, provider_request, fn
               %Delta{} -> :halt
               _event -> :ok
             end)

    assert requests(script) == 1
  end

  defp adapter(script) do
    assert {:ok, openai} =
             OpenAI.Runtime.new(
               [model: "qwen3-coder:30b", retry: %{max_attempts: 1, fixed_delay_ms: 0}],
               {ScriptedTransport, script}
             )

    assert {:ok, capabilities} =
             Capabilities.new(chat: true, streaming: true, tool_calls: true)

    {Ollama, %Runtime{capabilities: capabilities, model: "qwen3-coder:30b", openai: openai}}
  end

  defp request do
    assert {:ok, user} = Conversation.user("Read mix.exs")

    assert {:ok, tool} =
             Specification.new(
               name: "read_file",
               description: "Read a workspace file",
               input_schema: %{
                 "type" => "object",
                 "properties" => %{"path" => %{"type" => "string"}}
               }
             )

    assert {:ok, request} = Request.new(model: "ignored", messages: [user], tools: [tool])
    request
  end

  defp request_without_tools do
    assert {:ok, user} = Conversation.user("Explain tool syntax")
    assert {:ok, request} = Request.new(model: "ignored", messages: [user])
    request
  end

  defp start_script(responses) do
    start_supervised!({Agent, fn -> %{requests: 0, responses: responses} end})
  end

  defp requests(script) do
    Agent.get(script, & &1.requests)
  end

  defp malformed_stream(tool_close \\ "\n</tool_call>") do
    [
      sse(%{"content" => "Let me inspect it.\n\n<function=read_file>"}),
      sse(
        %{
          "content" => "\n<parameter=path>\nmix.exs\n</parameter>\n</function>" <> tool_close
        },
        "stop"
      ),
      done()
    ]
  end

  defp text_stream(content) do
    [sse(%{"content" => content}, "stop"), done()]
  end

  defp tool_stream do
    [sse(%{"tool_calls" => [tool_fragment()]}, "tool_calls"), done()]
  end

  defp malformed_completion do
    completion(%{
      "role" => "assistant",
      "content" =>
        "Let me inspect it.\n\n<function=read_file>\n<parameter=path>\nmix.exs\n" <>
          "</parameter>\n</function>\n</tool_call>"
    })
  end

  defp tool_completion do
    completion(
      %{
        "role" => "assistant",
        "content" => nil,
        "tool_calls" => [
          %{
            "id" => "call-1",
            "type" => "function",
            "function" => %{"name" => "read_file", "arguments" => ~s({"path":"mix.exs"})}
          }
        ]
      },
      "tool_calls"
    )
  end

  defp completion(message, finish_reason \\ "stop") do
    Jason.encode!(%{
      "choices" => [%{"index" => 0, "message" => message, "finish_reason" => finish_reason}]
    })
  end

  defp tool_fragment do
    %{
      "index" => 0,
      "id" => "call-1",
      "type" => "function",
      "function" => %{"name" => "read_file", "arguments" => ~s({"path":"mix.exs"})}
    }
  end

  defp sse(delta, finish_reason \\ nil) do
    payload = %{
      "choices" => [%{"index" => 0, "delta" => delta, "finish_reason" => finish_reason}]
    }

    "data: " <> Jason.encode!(payload) <> "\n\n"
  end

  defp done do
    "data: [DONE]\n\n"
  end
end
