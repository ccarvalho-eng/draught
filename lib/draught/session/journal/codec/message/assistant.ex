defmodule Draught.Session.Journal.Codec.Message.Assistant do
  @moduledoc """
  Encodes and decodes assistant content and tool calls under the active retention policy.
  """

  alias Draught.Conversation.Content
  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Session.Journal.Codec.Tool
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical assistant message."
  @spec encode(Assistant.t(), Retention.t()) :: map()
  def encode(%Assistant{} = message, %Retention{} = retention) do
    %{
      "content" => Enum.map(message.content, &encode_content/1),
      "role" => "assistant",
      "tool_calls" => Enum.map(message.tool_calls, &Tool.encode_call(&1, retention))
    }
  end

  @doc "Decodes a canonical assistant message."
  @spec decode(term()) :: {:ok, Assistant.t()} | :error
  def decode(%{"content" => content, "role" => "assistant", "tool_calls" => calls})
      when is_list(content) and is_list(calls) do
    with {:ok, decoded_content} <- decode_list(content, &decode_content/1),
         {:ok, decoded_calls} <- decode_list(calls, &Tool.decode_call/1) do
      result(Assistant.new(content: decoded_content, tool_calls: decoded_calls))
    end
  end

  def decode(_data) do
    :error
  end

  defp encode_content(content) do
    type =
      content
      |> Content.type()
      |> Atom.to_string()

    %{"text" => content.text, "type" => type}
  end

  defp decode_content(%{"text" => text, "type" => "text"}) do
    result(Text.new(text))
  end

  defp decode_content(%{"text" => text, "type" => "reasoning"}) do
    result(Reasoning.new(text))
  end

  defp decode_content(_data) do
    :error
  end

  defp decode_list(values, decoder) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, decoded} ->
      case decoder.(value) do
        {:ok, canonical} -> {:cont, {:ok, [canonical | decoded]}}
        :error -> {:halt, :error}
      end
    end)
    |> reverse()
  end

  defp reverse({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse(:error) do
    :error
  end

  defp result({:ok, value}) do
    {:ok, value}
  end

  defp result({:error, _error}) do
    :error
  end
end
