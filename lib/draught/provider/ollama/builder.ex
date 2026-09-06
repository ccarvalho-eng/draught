defmodule Draught.Provider.Ollama.Builder do
  @moduledoc false

  alias Draught.Provider.Ollama
  alias Draught.Provider.Ollama.Capability.Validator
  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Dependencies
  alias Draught.Provider.Ollama.Runtime
  alias Draught.Provider.Ollama.Selection
  alias Draught.Provider.OpenAI

  @doc "Builds an Ollama adapter from validated configuration and dependencies."
  @spec new(map() | keyword(), map() | keyword()) ::
          {:ok, Ollama.adapter()}
          | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def new(options, dependencies) do
    with {:ok, configuration} <- Configuration.new(options),
         {:ok, effects} <- Dependencies.new(dependencies),
         {:ok, model} <- Selection.resolve(configuration, effects.discovery_http),
         :ok <- Validator.validate(model.capabilities, configuration.required_capabilities),
         {:ok, openai} <- openai_runtime(configuration, model.name, effects) do
      {:ok, {Ollama, %Runtime{capabilities: model.capabilities, openai: openai}}}
    end
  end

  defp openai_runtime(configuration, model, effects) do
    configuration
    |> Configuration.for_model(model)
    |> OpenAI.Runtime.new(effects.provider_transport)
  end
end
