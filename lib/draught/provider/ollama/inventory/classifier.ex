defmodule Draught.Provider.Ollama.Inventory.Classifier do
  @moduledoc """
  Classifies a discovered Ollama model against required provider capabilities.

  The resulting inventory entry retains every missing requirement so callers can
  explain why a model is incompatible.
  """

  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama.Discovery.Model
  alias Draught.Provider.Ollama.Inventory.Compatible
  alias Draught.Provider.Ollama.Inventory.Incompatible

  @doc "Classifies a discovered model against every required capability."
  @spec classify(Model.t(), [Capabilities.feature()]) :: Compatible.t() | Incompatible.t()
  def classify(%Model{} = model, requirements) do
    missing = Enum.reject(requirements, &Capabilities.supports?(model.capabilities, &1))
    classification(model, missing)
  end

  defp classification(model, []) do
    Compatible.new(model)
  end

  defp classification(model, missing) do
    Incompatible.new(model, missing)
  end
end
