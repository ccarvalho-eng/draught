defmodule Draught.CLI.Interactive.Startup.Model do
  @moduledoc """
  Resolves the initial interactive model without weakening durable session bindings.

  Fresh local Ollama sessions use one bounded inventory snapshot. A single
  compatible model is selected automatically; several leave selection to the shell.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Model.Catalog
  alias Draught.CLI.Task

  @doc "Returns the initial model and bounded compatible inventory snapshot."
  @spec resolve(Configuration.t(), Dependencies.t()) ::
          {:ok, String.t() | nil, [String.t()]} | {:error, term()}
  def resolve(
        %Configuration{provider: :ollama, model: nil} = configuration,
        %Dependencies{task: %Task.Dependencies{provider: {Task.Provider.Local, _dependency}}} =
          dependencies
      ) do
    with {:ok, models} <- Catalog.list(configuration, dependencies) do
      automatic(models)
    end
  end

  def resolve(%Configuration{} = configuration, %Dependencies{} = dependencies) do
    case Task.Provider.build(configuration, dependencies.task.provider) do
      {:ok, selection} -> {:ok, selection.model, []}
      {:error, _error} = result -> result
    end
  end

  defp automatic([model]) do
    {:ok, model, [model]}
  end

  defp automatic([_first, _second | _models] = models) do
    {:ok, nil, models}
  end
end
