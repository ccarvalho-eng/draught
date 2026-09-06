# Ollama provider

`Draught.Provider.Ollama` uses Ollama's native API for model discovery and its OpenAI-compatible API for completions and streams.

## Construction

The default native endpoint is `http://localhost:11434`. No credential is read or sent.

```elixir
{:ok, adapter} =
  Draught.Provider.Ollama.new(
    model: "qwen3"
  )
```

Construction requests `/api/show` and validates the selected model before returning an adapter. If `model` is omitted, Draught requests `/api/tags` and selects the model only when exactly one is installed. Zero models and multiple models return configuration errors.

The default required capabilities are `:chat`, `:streaming`, and `:tool_calls`. Applications that do not expose tools can set a narrower requirement:

```elixir
{:ok, adapter} =
  Draught.Provider.Ollama.new(
    model: "chat-model",
    required_capabilities: [:chat, :streaming]
  )
```

## Configuration

| Option | Default | Meaning |
| --- | --- | --- |
| `base_url` | `http://localhost:11434` | Native Ollama server root. Draught derives the OpenAI-compatible `/v1` root from it. |
| `model` | `nil` | Installed model name. Omission enables single-model selection. |
| `required_capabilities` | `[:chat, :streaming, :tool_calls]` | Capabilities checked against `/api/show`. |
| `headers` | `%{}` | Additional headers for completion requests. |
| `timeouts` | OpenAI provider defaults | Bounded connect, receive, and request timeouts used for discovery and completion requests. |
| `retry` | OpenAI provider defaults | Bounded completion retry policy. |
| `limits` | OpenAI provider defaults | Response, SSE, output, and tool-call limits. |
| `reasoning_field` | `:reasoning` | OpenAI-compatible response field used for reasoning content. |

Generation options belong to each canonical request:

```elixir
{:ok, user} = Draught.Conversation.user("Summarize this module")

{:ok, request} =
  Draught.Provider.Request.new(
    model: "ignored-when-the-adapter-selects-a-model",
    messages: [user],
    options: %{temperature: 0.2, max_output_tokens: 500}
  )

Draught.Provider.complete(adapter, request)
```

## Failures

| Condition | Error code |
| --- | --- |
| Ollama is unavailable | `ollama_unavailable` |
| Discovery timeout | `ollama_timeout` |
| No models are installed | `ollama_no_models` |
| More than one model exists and none was selected | `ollama_model_required` |
| Selected model is absent | `ollama_model_not_found` |
| Required capability is absent | `ollama_unsupported_<capability>` |
| Discovery payload is invalid | `invalid_ollama_response` |
| Discovery response exceeds its configured limit | `ollama_response_too_large` |

Errors do not retain discovery response bodies, request headers, model output, or transport exceptions.

## Manual smoke procedure

This procedure uses `qwen3`, the representative model in Ollama's [tool-calling documentation](https://docs.ollama.com/capabilities/tool-calling).

1. Start Ollama and install the model:

   ```sh
   ollama pull qwen3
   ```

2. Start the project shell:

   ```sh
   iex -S mix
   ```

3. Construct a tool-capable request:

   ```elixir
   {:ok, adapter} = Draught.Provider.Ollama.new(model: "qwen3")
   {:ok, user} = Draught.Conversation.user("Call add with a=2 and b=3. Do not calculate it directly.")

   {:ok, tool} =
     Draught.Tool.Specification.new(
       name: "add",
       description: "Add two integers",
       input_schema: %{
         "type" => "object",
         "required" => ["a", "b"],
         "properties" => %{
           "a" => %{"type" => "integer"},
           "b" => %{"type" => "integer"}
         }
       }
     )

   {:ok, request} =
     Draught.Provider.Request.new(
       model: "qwen3",
       messages: [user],
       tools: [tool]
     )

   {:ok, response} = Draught.Provider.complete(adapter, request)
   response.finish_reason
   response.message.tool_calls
   ```

4. Confirm the finish reason is `:tool_calls` and the returned call is named `add` with integer arguments `a` and `b`.

The native endpoint contracts are documented by Ollama under [List models](https://docs.ollama.com/api/tags), [Show model details](https://docs.ollama.com/api-reference/show-model-details), and [OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility).
