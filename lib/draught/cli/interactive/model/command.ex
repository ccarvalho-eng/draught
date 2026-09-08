defmodule Draught.CLI.Interactive.Model.Command do
  @moduledoc """
  Handles interactive model inspection and pre-persistence selection.

  Ollama selections resolve only against a bounded compatible inventory. Other
  providers delegate exact model validation to their provider-construction boundary.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Model.Catalog
  alias Draught.CLI.Interactive.Model.Reference
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Task.Provider

  @type view :: {:models, [String.t()], String.t() | nil} | {:selected, String.t()}
  @type result :: {:ok, State.t(), view()} | {:error, term()}

  @doc "Lists compatible models or selects one for the current fresh session."
  @spec run(String.t() | nil, State.t(), Configuration.t(), Dependencies.t()) :: result()
  def run(nil, state, configuration, dependencies) do
    with {:ok, models} <- Catalog.list(configuration, dependencies),
         {:ok, displayed} <- State.display_models(state, models) do
      {:ok, displayed, {:models, models, state.model}}
    end
  end

  def run(reference, state, configuration, dependencies) do
    with :ok <- State.model_selectable(state),
         {:ok, model} <- resolve(reference, state, configuration, dependencies),
         {:ok, selected} <- State.select_model(state, model) do
      {:ok, selected, {:selected, model}}
    end
  end

  defp resolve(
         reference,
         state,
         %Configuration{provider: :ollama} = configuration,
         dependencies
       ) do
    case State.displayed_models(state) do
      {:ok, models} -> Reference.resolve(reference, models)
      {:error, :model_list_required} -> resolve_exact(reference, configuration, dependencies)
    end
  end

  defp resolve(reference, _state, %Configuration{} = configuration, dependencies) do
    selected = %{configuration | model: reference}

    case Provider.build(selected, dependencies.task.provider) do
      {:ok, selection} -> {:ok, selection.model}
      {:error, _error} = result -> result
    end
  end

  defp resolve_exact(reference, configuration, dependencies) do
    with {:ok, models} <- Catalog.list(configuration, dependencies) do
      exact_result(reference, models)
    end
  end

  defp exact_result(reference, models) do
    case Reference.exact(reference, models) do
      {:error, :not_found} -> positional_error(reference)
      {:ok, _model} = result -> result
    end
  end

  defp positional_error(reference) do
    case Integer.parse(reference) do
      {position, ""} when position > 0 -> {:error, :model_list_required}
      _result -> {:error, :not_found}
    end
  end
end
