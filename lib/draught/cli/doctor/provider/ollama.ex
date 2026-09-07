defmodule Draught.CLI.Doctor.Provider.Ollama do
  @moduledoc false

  alias Draught.CLI
  alias Draught.CLI.Doctor.Check
  alias Draught.CLI.Doctor.Provider.Ollama.Selected
  alias Draught.Error.Normalized
  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Inventory
  alias Draught.Validation.Error

  @doc "Checks Ollama connectivity and required model capabilities."
  @spec check(CLI.Configuration.t(), module()) :: Check.t()
  def check(%CLI.Configuration{} = configuration, discovery_http) do
    attributes = [base_url: configuration.base_url, model: configuration.model]

    case Configuration.new(attributes) do
      {:ok, ollama} -> diagnostics(ollama, discovery_http)
      {:error, %Error{}} -> Check.new("Ollama", :error, "configuration is invalid")
    end
  end

  defp diagnostics(%Configuration{model: nil} = configuration, discovery_http) do
    inventory(configuration, discovery_http)
  end

  defp diagnostics(%Configuration{model: model} = configuration, discovery_http) do
    Selected.check(configuration, model, discovery_http)
  end

  defp inventory(configuration, discovery_http) do
    case Inventory.list(configuration, discovery_http) do
      {:ok, entries} -> inventory_check(entries, configuration.model)
      {:error, %Normalized{} = error} -> normalized_check(error)
    end
  end

  defp inventory_check([], _selected_model) do
    Check.new(
      "Ollama",
      :error,
      "no models are installed",
      hint: "Install a tool-capable model with 'ollama pull <model>'.",
      details: %{"compatible_models" => [], "incompatible_models" => []}
    )
  end

  defp inventory_check(entries, selected_model) do
    compatible = Inventory.compatible(entries)
    incompatible = Inventory.incompatible(entries)
    details = details(compatible, incompatible)

    selection_check(selected_model, compatible, incompatible, details)
  end

  defp selection_check(nil, [], _incompatible, details) do
    Check.new(
      "Ollama",
      :error,
      "installed models do not provide the required agent capabilities",
      hint: "Install a model with chat, streaming, and tool-call support.",
      details: details
    )
  end

  defp selection_check(nil, [_compatible], _incompatible, details) do
    Check.new("Ollama", :ok, "1 compatible model installed", details: details)
  end

  defp selection_check(nil, compatible, _incompatible, details) do
    count = Enum.count(compatible)

    Check.new(
      "Ollama",
      :error,
      "#{count} compatible models require an explicit selection",
      hint: "Select a model in configuration or with --model.",
      details: details
    )
  end

  defp normalized_check(%Normalized{} = error) do
    Check.new(
      "Ollama",
      :error,
      error.message,
      hint: error.hint,
      details: %{"code" => error.code, "retryable" => error.retryable}
    )
  end

  defp details(compatible, incompatible) do
    %{
      "compatible_models" => Enum.map(compatible, & &1.model.name),
      "incompatible_models" => Enum.map(incompatible, & &1.model.name)
    }
  end
end
