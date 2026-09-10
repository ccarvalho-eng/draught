defmodule Draught.Provider.Ollama.Response.MalformedToolCall do
  @moduledoc """
  Detects the bare Qwen tool markup that Ollama can expose as assistant text.

  Detection is deliberately narrow. It never parses markup or converts model
  text into executable tool authority.
  """

  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Provider.Response

  @function_open "<function="
  @function_close "</function>"
  @tool_open "<tool_call>"
  @tool_close "</tool_call>"

  @doc "Classifies one canonical response without exposing or parsing its markup."
  @spec detect(Response.t()) :: :ok | :malformed
  def detect(%Response{
        finish_reason: :stop,
        message: %Assistant{content: content, tool_calls: []}
      }) do
    content
    |> text()
    |> classify()
  end

  def detect(%Response{}) do
    :ok
  end

  defp text(content) do
    content
    |> Enum.reduce([], fn
      %Text{text: fragment}, result -> [fragment | result]
      _part, result -> result
    end)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp classify(content) do
    trimmed = String.trim_trailing(content)

    malformed? =
      String.contains?(content, @function_open) and
        String.contains?(content, @function_close) and
        not String.contains?(content, @tool_open) and
        (String.ends_with?(trimmed, @function_close) or
           String.ends_with?(trimmed, @tool_close))

    classification(malformed?)
  end

  defp classification(true) do
    :malformed
  end

  defp classification(false) do
    :ok
  end
end
