defmodule Draught.Conversation.Interchange.Text.Encoder.Message.Tool do
  @moduledoc false

  alias Draught.Conversation.Interchange.Text.JSON
  alias Draught.Conversation.Interchange.Text.Options
  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  @doc "Encodes one canonical tool call."
  @spec encode_call(Call.t(), Options.t()) :: Jason.OrderedObject.t()
  def encode_call(%Call{} = call, options) do
    arguments = arguments(call.arguments, options)
    JSON.object([{"id", call.id}, {"name", call.name}, {"arguments", arguments}])
  end

  @doc "Encodes one canonical tool result."
  @spec encode_result(Result.t(), Options.t()) :: Jason.OrderedObject.t()
  def encode_result(%Result{} = result, options) do
    options
    |> Options.retained?(:tool_results)
    |> result_value(result)
  end

  defp arguments(arguments, options) do
    options
    |> Options.retained?(:tool_arguments)
    |> arguments_value(arguments)
  end

  defp arguments_value(true, arguments) do
    JSON.order(arguments)
  end

  defp arguments_value(false, _arguments) do
    JSON.object([])
  end

  defp result_value(true, result) do
    retained_result(result)
  end

  defp result_value(false, result) do
    redacted_result(result)
  end

  defp retained_result(%Result{error: nil} = result) do
    result_object(result, result.content)
  end

  defp retained_result(%Result{error: error} = result) do
    result_object(result, result.content, encode_error(error))
  end

  defp redacted_result(%Result{error: nil} = result) do
    result_object(result, "[tool result redacted]")
  end

  defp redacted_result(%Result{error: error} = result) do
    result_object(result, "[tool result redacted]", redacted_error(error))
  end

  defp result_object(result, content) do
    JSON.object([
      {"call_id", result.call_id},
      {"name", result.name},
      {"content", content},
      {"status", Atom.to_string(result.status)}
    ])
  end

  defp result_object(result, content, error) do
    JSON.object([
      {"call_id", result.call_id},
      {"name", result.name},
      {"content", content},
      {"status", Atom.to_string(result.status)},
      {"error", error}
    ])
  end

  defp encode_error(%Normalized{hint: nil} = error) do
    JSON.object([
      {"kind", Atom.to_string(error.kind)},
      {"code", error.code},
      {"message", error.message},
      {"retryable", error.retryable}
    ])
  end

  defp encode_error(%Normalized{} = error) do
    JSON.object([
      {"kind", Atom.to_string(error.kind)},
      {"code", error.code},
      {"message", error.message},
      {"retryable", error.retryable},
      {"hint", error.hint}
    ])
  end

  defp redacted_error(%Normalized{} = error) do
    JSON.object([
      {"kind", Atom.to_string(error.kind)},
      {"code", "redacted"},
      {"message", "Tool error details were redacted"},
      {"retryable", error.retryable}
    ])
  end
end
