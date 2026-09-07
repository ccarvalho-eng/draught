defmodule Draught.Conversation.Interchange.Text.Encoder.Message.Content do
  @moduledoc false

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Interchange.Text.JSON
  alias Draught.Conversation.Interchange.Text.Options

  @doc "Encodes one canonical assistant content part."
  @spec encode(Draught.Conversation.Content.t(), Options.t()) :: Jason.OrderedObject.t()
  def encode(%Text{text: text}, _options) do
    JSON.object([{"type", "text"}, {"text", text}])
  end

  def encode(%Reasoning{text: text}, options) do
    options
    |> Options.retained?(:reasoning)
    |> reasoning_text(text)
    |> reasoning()
  end

  defp reasoning(text) do
    JSON.object([{"type", "reasoning"}, {"text", text}])
  end

  defp reasoning_text(true, text) do
    text
  end

  defp reasoning_text(false, _text) do
    "[reasoning redacted]"
  end
end
