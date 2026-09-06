defmodule Draught.Provider.OpenAI.Request.Message.Assistant do
  @moduledoc """
  Serializes assistant content, reasoning, and tool calls.
  """

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Request.ToolCall

  @type reasoning_field :: :none | :reasoning | :reasoning_content

  @doc "Encodes one canonical assistant message."
  @spec encode(Draught.Conversation.Message.Assistant.t(), reasoning_field()) ::
          {:ok, map()} | {:error, Normalized.t()}
  def encode(%Draught.Conversation.Message.Assistant{} = message, reasoning_field) do
    encoded =
      %{"role" => "assistant", "content" => joined(message.content, Text)}
      |> put_reasoning(message.content, reasoning_field)
      |> put_tool_calls(message.tool_calls)

    validate(encoded, message.content, reasoning_field)
  end

  defp joined(parts, module) do
    values = for %{__struct__: ^module, text: text} <- parts, do: text

    case values do
      [] -> nil
      [_value | _rest] -> Enum.join(values)
    end
  end

  defp put_reasoning(message, _content, :none) do
    message
  end

  defp put_reasoning(message, content, field) do
    case joined(content, Reasoning) do
      nil -> message
      reasoning -> Map.put(message, Atom.to_string(field), reasoning)
    end
  end

  defp put_tool_calls(message, []) do
    message
  end

  defp put_tool_calls(message, calls) do
    Map.put(message, "tool_calls", Enum.map(calls, &ToolCall.encode/1))
  end

  defp validate(%{"content" => nil} = message, content, :none) do
    reasoning = joined(content, Reasoning)
    validate_unrepresented_reasoning(message, reasoning)
  end

  defp validate(message, _content, _reasoning_field) do
    {:ok, message}
  end

  defp validate_unrepresented_reasoning(%{"tool_calls" => [_call | _rest]} = message, _reasoning) do
    {:ok, message}
  end

  defp validate_unrepresented_reasoning(message, nil) do
    {:ok, message}
  end

  defp validate_unrepresented_reasoning(_message, _reasoning) do
    {:ok, error} =
      Normalized.new(
        :configuration,
        "reasoning_field_required",
        "assistant reasoning cannot be represented by the configured endpoint",
        retryable: false
      )

    {:error, error}
  end
end
