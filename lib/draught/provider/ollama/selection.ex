defmodule Draught.Provider.Ollama.Selection do
  @moduledoc false

  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.Ollama.Inventory
  alias Draught.Provider.Ollama.Inventory.Compatible
  alias Draught.Provider.Ollama.Protocol

  @doc "Selects and discovers the configured Ollama model."
  @spec resolve(Configuration.t(), module()) ::
          {:ok, Discovery.Model.t()} | {:error, Draught.Error.Normalized.t()}
  def resolve(%Configuration{model: nil} = configuration, http) do
    with {:ok, entries} <- Inventory.list(configuration, http) do
      select(entries)
    end
  end

  def resolve(%Configuration{model: model} = configuration, http) do
    discover(model, configuration, http)
  end

  defp select([]) do
    Protocol.no_models()
  end

  defp select(entries) do
    entries
    |> Inventory.compatible()
    |> select_compatible()
  end

  defp select_compatible([]) do
    Protocol.no_compatible_models()
  end

  defp select_compatible([%Compatible{model: model}]) do
    {:ok, model}
  end

  defp select_compatible([%Compatible{} | _entries]) do
    Protocol.model_required()
  end

  defp discover(model, configuration, http) do
    Discovery.fetch(model, discovery_options(configuration), http)
  end

  defp discovery_options(configuration) do
    Map.from_struct(configuration.discovery)
  end
end
