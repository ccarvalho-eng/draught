defmodule Draught.Conversation.Content do
  @moduledoc """
  Constructs and identifies provider-neutral conversation content parts.
  """

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @types [:reasoning, :text]

  @type t :: Text.t() | Reasoning.t()

  @doc "Builds a typed content part from external attributes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:type, :text]),
         {:ok, raw_type} <- Attributes.fetch_required(normalized, :type),
         {:ok, type} <- Value.enum(raw_type, @types, [:type]),
         {:ok, text} <- Value.required_string(normalized, :text) do
      build(type, text)
    end
  end

  @doc "Returns the stable type of a content part."
  @spec type(t()) :: :reasoning | :text
  def type(%Text{}) do
    :text
  end

  def type(%Reasoning{}) do
    :reasoning
  end

  @doc "Normalizes a text string or text part at the supplied path."
  @spec text(term(), [term()]) :: Error.result(Text.t())
  def text(value, path \\ [:content]) do
    case value do
      %Text{text: text} -> Text.new(text, path)
      binary when is_binary(binary) -> Text.new(binary, path)
      _value -> Error.single(path, :invalid_type, "must be text content")
    end
  end

  defp build(:text, text) do
    Text.new(text)
  end

  defp build(:reasoning, text) do
    Reasoning.new(text)
  end
end
