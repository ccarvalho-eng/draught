defmodule Draught.Provider.Ollama.Inventory.Compatible do
  @moduledoc """
  An installed Ollama model that satisfies every required capability.
  """

  alias Draught.Provider.Ollama.Discovery.Model

  @enforce_keys [:model]
  defstruct [:model]

  @type t :: %__MODULE__{model: Model.t()}

  @doc "Builds a compatible inventory entry from a discovered model."
  @spec new(Model.t()) :: t()
  def new(%Model{} = model) do
    %__MODULE__{model: model}
  end
end
