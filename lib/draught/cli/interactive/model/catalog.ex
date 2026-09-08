defmodule Draught.CLI.Interactive.Model.Catalog do
  @moduledoc """
  Routes bounded compatible-model discovery by configured provider.

  Providers without a local inventory return an explicit unsupported result;
  exact model validation remains the provider-construction boundary's concern.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Model.Catalog.Ollama

  @doc "Lists compatible models exposed by the configured provider."
  @spec list(Configuration.t(), Dependencies.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def list(%Configuration{provider: :ollama} = configuration, %Dependencies{} = dependencies) do
    Ollama.list(configuration, dependencies.discovery_http)
  end

  def list(%Configuration{}, %Dependencies{}) do
    {:error, :model_catalog_unavailable}
  end
end
