defmodule Draught.CLI.Doctor.Provider.Ollama.Selected.Result do
  @moduledoc """
  Converts selected-model discovery outcomes into bounded diagnostic checks.
  """

  alias Draught.CLI.Doctor.Check
  alias Draught.Error.Normalized
  alias Draught.Provider.Ollama.Inventory.Compatible
  alias Draught.Provider.Ollama.Inventory.Incompatible

  @doc "Converts a selected-model classification or failure into a safe diagnostic check."
  @spec from(Compatible.t() | Incompatible.t() | Normalized.t()) :: Check.t()
  def from(%Compatible{model: model}) do
    Check.new(
      "Ollama",
      :ok,
      "selected model is compatible",
      details: %{"compatible_models" => [model.name], "incompatible_models" => []}
    )
  end

  def from(%Incompatible{model: model, missing_capabilities: missing}) do
    Check.new(
      "Ollama",
      :error,
      "selected model lacks required agent capabilities",
      hint: "Select a compatible installed model.",
      details: %{
        "compatible_models" => [],
        "incompatible_models" => [model.name],
        "missing_capabilities" => Enum.map(missing, &Atom.to_string/1)
      }
    )
  end

  def from(%Normalized{} = error) do
    Check.new(
      "Ollama",
      :error,
      error.message,
      hint: error.hint,
      details: %{"code" => error.code, "retryable" => error.retryable}
    )
  end
end
