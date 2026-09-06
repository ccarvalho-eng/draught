defmodule Draught.Event.Provider.Delta do
  @moduledoc """
  An ordered text or reasoning fragment emitted by a provider stream.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @kinds [:reasoning, :text]

  @enforce_keys [:kind, :content]
  defstruct [:kind, :content]

  @type kind :: :reasoning | :text
  @type t :: %__MODULE__{kind: kind(), content: String.t()}

  @doc "Builds a validated provider delta."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:kind, :content]),
         {:ok, raw_kind} <- Attributes.fetch_required(normalized, :kind),
         {:ok, kind} <- Value.enum(raw_kind, @kinds, [:kind]),
         {:ok, content} <- Value.required_string(normalized, :content) do
      {:ok, %__MODULE__{kind: kind, content: content}}
    end
  end
end
