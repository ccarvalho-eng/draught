defmodule Draught.CLI.Interactive.Session.Command do
  @moduledoc """
  Interprets idle interactive session-management commands through the catalog boundary.

  Selection prepares the replacement session completely before changing shell
  state. Immutable IDs remain separate from optional human-readable labels.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Session.Lookup
  alias Draught.CLI.Interactive.Session.Reference
  alias Draught.CLI.Interactive.Startup
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Session.Catalog

  @type view ::
          {:archived, String.t()}
          | {:renamed, String.t()}
          | {:restored, String.t()}
          | {:selected, String.t()}
          | {:sessions, [Catalog.Entry.t()], :active | :all | :archived}
  @type result ::
          {:ok, State.t(), Configuration.t(), view()}
          | {:error, Startup.category(), term()}
          | {:error, term()}

  @doc "Executes one session command without performing terminal input or output."
  @spec run(
          atom(),
          String.t() | nil,
          State.t(),
          Configuration.t(),
          Invocation.t(),
          Dependencies.t()
        ) :: result()
  def run(:sessions, _argument, state, configuration, _invocation, dependencies) do
    with {:ok, entries} <- Lookup.list(state, dependencies) do
      {:ok, state, configuration, {:sessions, entries, :all}}
    end
  end

  def run(:resume, nil, state, configuration, _invocation, dependencies) do
    with {:ok, entries} <- Lookup.list(state, dependencies) do
      {:ok, state, configuration, {:sessions, entries, :active}}
    end
  end

  def run(:resume, reference, state, configuration, invocation, dependencies) do
    with {:ok, entry} <- Lookup.resolve(reference, :active, state, dependencies),
         {:ok, selected, base_configuration} <-
           Startup.select(entry.id, configuration, state.workspace, invocation, dependencies),
         {:ok, next_state} <- State.select(state, selected) do
      {:ok, next_state, base_configuration, {:selected, entry.id}}
    end
  end

  def run(:new, label, state, configuration, _invocation, dependencies) do
    with {:ok, identifier} <- Reference.fresh(label, dependencies),
         :ok <- Lookup.ensure_unused(identifier, state, dependencies),
         {:ok, selected, base_configuration} <-
           Startup.fresh(
             identifier,
             identifier,
             configuration,
             state.workspace,
             dependencies
           ),
         {:ok, next_state} <- State.select(state, selected) do
      {:ok, next_state, base_configuration, {:selected, identifier}}
    end
  end

  def run(:rename, label, state, configuration, _invocation, dependencies) do
    with {:ok, validated} <- Reference.name(label),
         {:ok, next_state} <- rename(state, validated, dependencies) do
      {:ok, next_state, configuration, {:renamed, validated}}
    end
  end

  def run(:archive, reference, state, configuration, _invocation, dependencies) do
    with {:ok, identifier} <- Reference.archive(reference, state),
         {:ok, entry} <- Lookup.resolve(identifier, :any, state, dependencies),
         {:ok, next_state, base_configuration} <-
           replacement_before_archive(
             entry.id,
             state,
             configuration,
             dependencies
           ),
         {:ok, _archived} <-
           Catalog.archive(
             dependencies.catalog,
             state.workspace,
             entry.id,
             environment(dependencies)
           ) do
      {:ok, next_state, base_configuration, {:archived, entry.id}}
    end
  end

  def run(:restore, nil, state, configuration, _invocation, dependencies) do
    with {:ok, entries} <- Lookup.list(state, dependencies) do
      {:ok, state, configuration, {:sessions, entries, :archived}}
    end
  end

  def run(:restore, reference, state, configuration, _invocation, dependencies) do
    with {:ok, entry} <- Lookup.resolve(reference, :any, state, dependencies),
         {:ok, _restored} <-
           Catalog.restore(
             dependencies.catalog,
             state.workspace,
             entry.id,
             environment(dependencies)
           ) do
      {:ok, state, configuration, {:restored, entry.id}}
    end
  end

  defp rename(%State{persisted?: false}, _label, _dependencies) do
    {:error, :session_not_persisted}
  end

  defp rename(%State{persisted?: true} = state, label, dependencies) do
    with {:ok, _entry} <-
           Catalog.rename(
             dependencies.catalog,
             state.workspace,
             state.session_id,
             label,
             environment(dependencies)
           ) do
      State.rename(state, label)
    end
  end

  defp replacement_before_archive(
         identifier,
         %State{session_id: identifier} = state,
         configuration,
         dependencies
       ) do
    with {:ok, fresh_identifier} <- Reference.fresh(nil, dependencies),
         :ok <- Lookup.ensure_unused(fresh_identifier, state, dependencies),
         {:ok, selected, base_configuration} <-
           Startup.fresh(
             fresh_identifier,
             fresh_identifier,
             configuration,
             state.workspace,
             dependencies
           ),
         {:ok, next_state} <- State.select(state, selected) do
      {:ok, next_state, base_configuration}
    end
  end

  defp replacement_before_archive(
         _identifier,
         state,
         configuration,
         _dependencies
       ) do
    {:ok, state, configuration}
  end

  defp environment(%Dependencies{system: {system, configuration}}) do
    system.environment(configuration)
  end
end
