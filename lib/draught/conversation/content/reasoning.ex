defmodule Draught.Conversation.Content.Reasoning do
  @moduledoc """
  A non-empty UTF-8 reasoning part separated from user-visible text.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:text]
  defstruct [:text]

  @type t :: %__MODULE__{text: String.t()}

  @doc "Builds a validated reasoning part."
  @spec new(term(), [term()]) :: Error.result(t())
  def new(text, path \\ [:text]) do
    with {:ok, validated} <- Value.string(text, path) do
      {:ok, %__MODULE__{text: validated}}
    end
  end
end
