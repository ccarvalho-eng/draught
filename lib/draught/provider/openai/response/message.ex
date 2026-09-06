defmodule Draught.Provider.OpenAI.Response.Message do
  @moduledoc """
  Decodes compatible assistant content, reasoning, and tool calls.
  """

  alias Draught.Conversation.Message.Assistant
  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Response.Protocol
  alias Draught.Provider.OpenAI.Response.ToolCall

  @doc "Decodes a provider assistant message for a normalized finish reason."
  @spec decode(term(), Draught.Provider.Response.finish_reason()) ::
          {:ok, Assistant.t()} | {:error, Normalized.t()}
  def decode(%{"role" => "assistant"} = message, finish_reason) do
    with {:ok, content} <- content(message),
         {:ok, reasoning} <- reasoning(message),
         {:ok, tool_calls} <- tool_calls(message) do
      build(content, reasoning, tool_calls, finish_reason)
    end
  end

  def decode(_message, _finish_reason) do
    Protocol.error("invalid_message", "provider assistant message is malformed")
  end

  defp content(message) do
    message
    |> Map.get("content")
    |> optional_text()
  end

  defp tool_calls(message) do
    message
    |> Map.get("tool_calls")
    |> ToolCall.decode_all()
  end

  defp optional_text(nil) do
    {:ok, nil}
  end

  defp optional_text("") do
    {:ok, nil}
  end

  defp optional_text(value) when is_binary(value) do
    optional_text_result(String.valid?(value), value)
  end

  defp optional_text(_value) do
    invalid_message()
  end

  defp optional_text_result(true, value) do
    {:ok, value}
  end

  defp optional_text_result(false, _value) do
    invalid_message()
  end

  defp reasoning(message) do
    with {:ok, reasoning} <- optional_text(Map.get(message, "reasoning")),
         {:ok, reasoning_content} <- optional_text(Map.get(message, "reasoning_content")) do
      select_reasoning(reasoning, reasoning_content)
    end
  end

  defp select_reasoning(nil, nil) do
    {:ok, nil}
  end

  defp select_reasoning(value, nil) do
    {:ok, value}
  end

  defp select_reasoning(nil, value) do
    {:ok, value}
  end

  defp select_reasoning(_reasoning, _reasoning_content) do
    Protocol.error("invalid_message", "provider returned ambiguous reasoning fields")
  end

  defp build(nil, nil, [], :content_filter) do
    {:ok, Assistant.filtered()}
  end

  defp build(content, reasoning, tool_calls, _finish_reason) do
    %{}
    |> put_optional(:content, content)
    |> put_optional(:reasoning, reasoning)
    |> Map.put(:tool_calls, tool_calls)
    |> Assistant.new()
    |> Protocol.canonical("invalid_message", "provider assistant message is malformed")
  end

  defp put_optional(attributes, _key, nil) do
    attributes
  end

  defp put_optional(attributes, key, value) do
    Map.put(attributes, key, value)
  end

  defp invalid_message do
    Protocol.error("invalid_message", "provider assistant message is malformed")
  end
end
