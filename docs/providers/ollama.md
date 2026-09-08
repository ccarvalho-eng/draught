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

Construction requests `/api/show` and validates the selected model before returning an adapter. If `model` is omitted, Draught requests `/api/tags`, fetches bounded details for each installed model through `/api/show`, and filters the inventory by the required capabilities. Selection happens only after filtering: exactly one compatible model is selected automatically, while zero or multiple compatible models return errors with selection guidance.

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

## Inventory and selection

Inventory discovery preserves the order returned by Ollama. Each entry is classified as compatible or incompatible against the complete required capability set. Incompatible models remain visible to diagnostics but are excluded from automatic selection.

Discovery is bounded to 16 installed models and is sequential. A larger automatic inventory returns `ollama_inventory_too_large` and requires an explicit model selection. A failure while fetching any installed model's details fails the inventory operation rather than returning a partial result. Selection then follows these rules:

- No installed models returns `ollama_no_models`.
- Installed models with no compatible entry return `ollama_no_compatible_models`.
- One compatible entry is selected automatically when no model was requested.
- More than one compatible entry requires an explicit model and returns `ollama_model_required` otherwise.
- An explicitly selected missing or incompatible model returns its normalized provider error.

The interactive CLI handles the multiple-compatible-model case inside its shell: `/model` lists the compatible inventory and `/model REF` selects an exact name or one-based position before the first durable turn. A persisted session cannot change its recorded model binding. One-shot commands continue to require an explicit model when automatic selection is ambiguous.

The read-only `draught doctor` command uses this inventory when model selection is automatic. When a model is explicit, doctor requests and checks only that model. See [Getting started](../getting-started.md) for local setup and model selection.

## Failures

| Condition | Error code |
| --- | --- |
| Ollama is unavailable | `ollama_unavailable` |
| Discovery timeout | `ollama_timeout` |
| No models are installed | `ollama_no_models` |
| Installed models but no compatible model | `ollama_no_compatible_models` |
| More than one compatible model exists and none was selected | `ollama_model_required` |
| Automatic inventory exceeds 16 installed models | `ollama_inventory_too_large` |
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
