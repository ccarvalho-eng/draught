defmodule Draught.CLI.Task.Provider.Local.Ollama do
  @moduledoc false

  alias Draught.CLI.Configuration
  alias Draught.CLI.Provider.Requirements
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Provider.Ollama

  @doc "Builds the selected Ollama adapter through injected transports."
  @spec build(Configuration.t(), map()) :: Draught.CLI.Task.Provider.Adapter.result()
  def build(%Configuration{} = configuration, dependencies) do
    options = [
      base_url: configuration.base_url,
      model: configuration.model,
      headers: configuration.headers,
      required_capabilities: Requirements.agent()
    ]

    with {:ok, adapter} <- Ollama.new(options, dependencies),
         {:ok, model} <- Ollama.selected_model(adapter) do
      Selection.new(adapter, model)
    end
  end
end
