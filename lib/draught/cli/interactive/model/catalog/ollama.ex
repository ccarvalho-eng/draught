defmodule Draught.CLI.Interactive.Model.Catalog.Ollama do
  @moduledoc """
  Projects the bounded Ollama inventory into compatible model names for the shell.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Provider.Requirements
  alias Draught.Provider.Ollama.Inventory
  alias Draught.Provider.Ollama.Protocol

  @doc "Lists installed Ollama models that satisfy agent execution requirements."
  @spec list(Configuration.t(), module()) :: {:ok, [String.t()]} | {:error, term()}
  def list(%Configuration{} = configuration, discovery_http) do
    with {:ok, ollama} <- ollama_configuration(configuration),
         {:ok, entries} <- Inventory.list(ollama, discovery_http) do
      compatible(entries)
    end
  end

  defp ollama_configuration(configuration) do
    Draught.Provider.Ollama.Configuration.new(
      base_url: configuration.base_url,
      headers: configuration.headers,
      required_capabilities: Requirements.agent()
    )
  end

  defp compatible([]) do
    Protocol.no_models()
  end

  defp compatible(entries) do
    entries
    |> Inventory.compatible()
    |> compatible_names()
  end

  defp compatible_names([]) do
    Protocol.no_compatible_models()
  end

  defp compatible_names(entries) do
    {:ok, Enum.map(entries, & &1.model.name)}
  end
end
