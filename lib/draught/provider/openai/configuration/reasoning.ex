defmodule Draught.Provider.OpenAI.Configuration.Reasoning do
  @moduledoc """
  Selects the compatible wire field used to send assistant reasoning history.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @fields [:none, :reasoning, :reasoning_content]

  @doc "Builds a supported reasoning-field selection."
  @spec new(term()) :: Error.result(:none | :reasoning | :reasoning_content)
  def new(value) do
    Value.enum(value, @fields, [:reasoning_field])
  end
end
