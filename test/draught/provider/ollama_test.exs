defmodule Draught.Provider.OllamaTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Provider
  alias Draught.Provider.Ollama
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Response
  alias Draught.Provider.Request

  defmodule DiscoveryHTTP do
    @behaviour Draught.Provider.Ollama.Discovery.HTTP

    @impl Draught.Provider.Ollama.Discovery.HTTP
    def request(method, url, body, _configuration) do
      send(self(), {:discovery_request, method, url, body})

      receive do
        {:discovery_response, response} -> response
      end
    end
  end

  defmodule ProviderTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    alias Draught.Provider.OpenAI.Transport.Response

    @impl Draught.Provider.OpenAI.Transport
    def complete(request, owner) do
      send(owner, {:provider_request, request})
      {:ok, %Response{status: 200, body: complete_body()}}
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(request, owner, state, reducer) do
      send(owner, {:provider_stream_request, request})
      chunks = [sse("streamed"), "data: [DONE]\n\n"]
      {final, _emitted} = reduce(chunks, state, reducer)
      {:ok, %Response{status: 200}, final}
    end

    defp complete_body do
      Jason.encode!(%{
        "choices" => [
          %{
            "index" => 0,
            "message" => %{"role" => "assistant", "content" => "ok"},
            "finish_reason" => "stop"
          }
        ]
      })
    end

    defp sse(content) do
      payload = %{
        "choices" => [
          %{"index" => 0, "delta" => %{"content" => content}, "finish_reason" => "stop"}
        ]
      }

      "data: " <> Jason.encode!(payload) <> "\n\n"
    end

    defp reduce(chunks, initial, reducer) do
      Enum.reduce_while(chunks, {initial, false}, fn chunk, {state, emitted} ->
        case reducer.(chunk, state) do
          {:cont, updated, output} -> {:cont, {updated, emitted or output}}
          {:halt, updated, output} -> {:halt, {updated, emitted or output}}
        end
      end)
    end
  end

  test "selects one installed model and builds a keyless adapter" do
    queue_list(["qwen3:8b"])
    queue_model(["completion", "tools", "thinking"], 32_768)

    assert {:ok, adapter} = Ollama.new([], dependencies())
    assert {:ok, capabilities} = Provider.capabilities(adapter)
    assert capabilities.chat
    assert capabilities.streaming
    assert capabilities.tool_calls
    assert capabilities.reasoning
    assert capabilities.context_window == 32_768

    assert_receive {:discovery_request, :get, "http://localhost:11434/api/tags", nil}

    assert_receive {:discovery_request, :post, "http://localhost:11434/api/show",
                    %{"model" => "qwen3:8b"}}

    assert {:ok, _response} = Provider.complete(adapter, request("request-model"))
    assert_receive {:provider_request, provider_request}
    assert provider_request.url == "http://localhost:11434/v1/chat/completions"
    assert provider_request.body["model"] == "qwen3:8b"
    assert provider_request.body["temperature"] == 0.25
    refute Map.has_key?(provider_request.headers, "authorization")
  end

  test "uses an explicit model without listing and accepts endpoint and timeout overrides" do
    queue_model(["completion"], nil)

    options = [
      base_url: "http://ollama.test:2233/root",
      model: "chat:latest",
      required_capabilities: [:chat, :streaming],
      timeouts: %{connect_ms: 111, receive_ms: 222, request_ms: 333}
    ]

    assert {:ok, adapter} = Ollama.new(options, dependencies())
    assert_receive {:discovery_request, :post, "http://ollama.test:2233/root/api/show", _body}
    refute_receive {:discovery_request, :get, _url, _body}

    assert {:ok, _response} = Provider.complete(adapter, request("ignored"))
    assert_receive {:provider_request, provider_request}
    assert provider_request.url == "http://ollama.test:2233/root/v1/chat/completions"
    assert provider_request.connect_timeout_ms == 111
    assert provider_request.receive_timeout_ms == 222
    assert provider_request.request_timeout_ms == 333
  end

  test "streams through the selected OpenAI-compatible model" do
    queue_model(["completion", "tools"], nil)
    assert {:ok, adapter} = Ollama.new([model: "tools:latest"], dependencies())
    parent = self()

    assert {:ok, _response} =
             Provider.stream(adapter, request("ignored"), fn event ->
               send(parent, {:event, event})
               :ok
             end)

    assert_receive {:provider_stream_request, provider_request}
    assert provider_request.body["model"] == "tools:latest"
    assert_receive {:event, %Delta{kind: :text, content: "streamed"}}
    assert_receive {:event, %Completed{}}
    refute_receive {:event, _event}
  end

  test "requires tool calling by default" do
    queue_model(["completion"], nil)

    assert {:error,
            %Normalized{
              kind: :capability,
              code: "ollama_unsupported_tool_calls",
              retryable: false
            }} = Ollama.new([model: "chat-only"], dependencies())
  end

  test "reports when automatic model selection has zero or multiple choices" do
    queue_list([])

    assert {:error, %Normalized{code: "ollama_no_models"}} =
             Ollama.new([], dependencies())

    queue_list(["one", "two"])
    queue_model(["completion", "tools"], nil)
    queue_model(["completion", "tools"], nil)

    assert {:error,
            %Normalized{
              code: "ollama_model_required",
              hint: "Select one of the compatible installed models explicitly."
            }} =
             Ollama.new([], dependencies())
  end

  test "reports when installed models do not meet the required capabilities" do
    queue_list(["chat-only", "reasoning-only"])
    queue_model(["completion"], nil)
    queue_model(["thinking"], nil)

    assert {:error,
            %Normalized{
              kind: :capability,
              code: "ollama_no_compatible_models",
              hint: "Install a model that advertises every required capability."
            }} = Ollama.new([], dependencies())
  end

  test "selects the only compatible model after inventory classification" do
    queue_list(["chat-only", "agent", "reasoning-only"])
    queue_model(["completion"], nil)
    queue_model(["completion", "tools"], nil)
    queue_model(["thinking"], nil)

    assert {:ok, adapter} = Ollama.new([], dependencies())
    assert {:ok, _response} = Provider.complete(adapter, request("ignored"))
    assert_receive {:provider_request, provider_request}
    assert provider_request.body["model"] == "agent"
  end

  test "propagates an unavailable service without activating another provider" do
    send(self(), {:discovery_response, {:error, Failure.new(:unavailable)}})

    assert {:error, %Normalized{code: "ollama_unavailable"}} =
             Ollama.new([], dependencies())
  end

  defp dependencies do
    [
      discovery_http: DiscoveryHTTP,
      provider_transport: {ProviderTransport, self()}
    ]
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})
    send(self(), {:discovery_response, {:ok, %Response{status: 200, body: body}}})
  end

  defp queue_model(capabilities, context_window) do
    model_info = model_info(context_window)
    body = Jason.encode!(%{"capabilities" => capabilities, "model_info" => model_info})
    send(self(), {:discovery_response, {:ok, %Response{status: 200, body: body}}})
  end

  defp model_info(nil) do
    %{}
  end

  defp model_info(context_window) do
    %{"general.architecture" => "test", "test.context_length" => context_window}
  end

  defp request(model) do
    assert {:ok, user} = Conversation.user("Hello")

    assert {:ok, request} =
             Request.new(
               model: model,
               messages: [user],
               options: %{temperature: 0.25}
             )

    request
  end
end
