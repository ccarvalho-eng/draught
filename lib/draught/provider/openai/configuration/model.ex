defmodule Draught.Provider.OpenAI.Configuration.Model do
  @moduledoc """
  Validates the optional configuration-level model override.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @doc "Builds an optional non-empty model identifier."
  @spec new(term()) :: Error.result(String.t() | nil)
  def new(nil) do
    {:ok, nil}
  end

  def new(value) do
    Value.string(value, [:model])
  end
end
