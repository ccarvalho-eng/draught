defmodule Draught.CLI.Doctor.Provider.Ollama.Selected do
  @moduledoc """
  Validates an explicitly selected Ollama model without scanning unrelated installed models.
  """

  alias Draught.CLI.Doctor.Check
  alias Draught.CLI.Doctor.Provider.Ollama.Selected.Result
  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.Ollama.Inventory.Classifier

  @doc "Fetches and classifies only the explicitly selected Ollama model."
  @spec check(Configuration.t(), String.t(), module()) :: Check.t()
  def check(%Configuration{} = configuration, model, discovery_http) do
    options = Map.from_struct(configuration.discovery)

    case Discovery.fetch(model, options, discovery_http) do
      {:ok, discovered} ->
        discovered
        |> Classifier.classify(configuration.required_capabilities)
        |> Result.from()

      {:error, error} ->
        Result.from(error)
    end
  end
end
