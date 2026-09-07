defmodule Draught.Provider.Ollama.Inventory.Incompatible do
  @moduledoc """
  An installed Ollama model and the required capabilities it does not advertise.
  """

  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama.Discovery.Model

  @enforce_keys [:missing_capabilities, :model]
  defstruct [:missing_capabilities, :model]

  @type t :: %__MODULE__{
          missing_capabilities: nonempty_list(Capabilities.feature()),
          model: Model.t()
        }

  @doc "Builds an incompatible inventory entry from a discovered model and missing features."
  @spec new(Model.t(), nonempty_list(Capabilities.feature())) :: t()
  def new(%Model{} = model, [_feature | _features] = missing_capabilities) do
    %__MODULE__{model: model, missing_capabilities: missing_capabilities}
  end
end
