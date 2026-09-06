defmodule Draught.Provider.OpenAI.Stream.Accumulator.Finalizer do
  @moduledoc "Constructs a canonical response from completed stream state."

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.Response

  @doc "Builds a provider-neutral response from validated accumulated values."
  @spec build(
          [String.t()],
          [String.t()],
          [Draught.Tool.Call.t()],
          Response.finish_reason(),
          term()
        ) ::
          {:ok, Response.t()} | {:error, Draught.Error.Normalized.t()}
  def build(text, reasoning, calls, finish_reason, usage) do
    with {:ok, content} <- content(text, reasoning),
         {:ok, message} <- message(content, calls, finish_reason) do
      [message: message, finish_reason: finish_reason, usage: usage]
      |> Response.new()
      |> Protocol.canonical("invalid_stream_finish", "Provider stream final state is invalid")
    end
  end

  defp content(text, reasoning) do
    with {:ok, text_parts} <- parts(Enum.reverse(text), :text),
         {:ok, reasoning_parts} <- parts(Enum.reverse(reasoning), :reasoning) do
      {:ok, text_parts ++ reasoning_parts}
    end
  end

  defp parts(values, kind) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, parts} ->
      case part(value, kind) do
        {:ok, content} -> {:cont, {:ok, [content | parts]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse_parts()
  end

  defp part(value, :text) do
    value
    |> Text.new()
    |> Protocol.canonical("invalid_stream_finish", "Provider stream text is invalid")
  end

  defp part(value, :reasoning) do
    value
    |> Reasoning.new()
    |> Protocol.canonical("invalid_stream_finish", "Provider stream reasoning is invalid")
  end

  defp reverse_parts({:ok, parts}) do
    {:ok, Enum.reverse(parts)}
  end

  defp reverse_parts({:error, _error} = result) do
    result
  end

  defp message([], [], :content_filter) do
    {:ok, Assistant.filtered()}
  end

  defp message(content, calls, _finish_reason) do
    [content: content, tool_calls: calls]
    |> Assistant.new()
    |> Protocol.canonical("invalid_stream_finish", "Provider stream output is incomplete")
  end
end
