defmodule Draught.Provider.Ollama.Selection do
  @moduledoc false

  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.Ollama.Protocol

  @doc "Selects and discovers the configured Ollama model."
  @spec resolve(Configuration.t(), module()) ::
          {:ok, Discovery.Model.t()} | {:error, Draught.Error.Normalized.t()}
  def resolve(%Configuration{model: nil} = configuration, http) do
    with {:ok, models} <-
           configuration
           |> discovery_options()
           |> Discovery.list(http),
         {:ok, selected} <- select(models) do
      discover(selected, configuration, http)
    end
  end

  def resolve(%Configuration{model: model} = configuration, http) do
    discover(model, configuration, http)
  end

  defp select([]) do
    Protocol.no_models()
  end

  defp select([model]) do
    {:ok, model}
  end

  defp select(_models) do
    Protocol.model_required()
  end

  defp discover(model, configuration, http) do
    Discovery.fetch(model, discovery_options(configuration), http)
  end

  defp discovery_options(configuration) do
    Map.from_struct(configuration.discovery)
  end
end
