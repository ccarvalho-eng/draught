defmodule Draught.Conversation.Interchange.Text.JSON do
  @moduledoc """
  Constructs deterministically ordered JSON values for text interchange.

  Nested validated maps are sorted recursively before encoding so equivalent
  documents produce stable extension bytes.
  """

  alias Jason.OrderedObject

  @doc "Builds a JSON object with an explicit property order."
  @spec object([{String.t(), term()}]) :: OrderedObject.t()
  def object(entries) do
    OrderedObject.new(entries)
  end

  @doc "Recursively orders the keys of validated JSON-compatible data."
  @spec order(Draught.Validation.JSON.value()) :: term()
  def order(value) when is_map(value) do
    entries =
      value
      |> Enum.sort_by(fn {key, _item} -> key end)
      |> Enum.map(fn {key, item} -> {key, order(item)} end)

    object(entries)
  end

  def order(value) when is_list(value) do
    Enum.map(value, &order/1)
  end

  def order(value) do
    value
  end
end
