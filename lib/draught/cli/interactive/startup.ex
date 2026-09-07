defmodule Draught.CLI.Interactive.Startup do
  @moduledoc """
  Resolves trusted configuration, provider selection, and session identity for the shell.

  Provider discovery completes before the first prompt so the opening card
  reports the effective model rather than an unresolved automatic setting.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Startup.Resume
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Task.Provider
  alias Draught.Session.Identifier

  @type category :: :configuration | :internal | :provider | :session
  @type result ::
          {:ok, State.t(), Configuration.t()}
          | {:error, category(), term()}

  @doc "Prepares the effective display state and task configuration for a shell."
  @spec prepare(Invocation.t(), Dependencies.t()) :: result()
  def prepare(%Invocation{} = invocation, %Dependencies{} = dependencies) do
    with {:ok, configuration, workspace} <- load(invocation, dependencies),
         {:ok, identifier} <- session_identifier(invocation, dependencies),
         {:ok, bound_configuration, label} <-
           Resume.bind(
             invocation,
             configuration,
             workspace,
             identifier,
             dependencies
           ) do
      prepare_selected(
        invocation,
        configuration,
        bound_configuration,
        workspace,
        identifier,
        label,
        dependencies
      )
    end
  end

  @doc "Prepares an existing session from the shell's unchanged base configuration."
  @spec select(
          String.t(),
          Configuration.t(),
          String.t(),
          Invocation.t(),
          Dependencies.t()
        ) :: result()
  def select(identifier, configuration, workspace, invocation, dependencies) do
    selected = %{
      invocation
      | command: :interactive,
        prompt: nil,
        resume: identifier,
        session: nil
    }

    with {:ok, bound, label} <-
           Resume.bind(selected, configuration, workspace, identifier, dependencies) do
      prepare_selected(
        selected,
        configuration,
        bound,
        workspace,
        identifier,
        label,
        dependencies
      )
    end
  end

  @doc "Prepares a fresh unpersisted session from the shell's base configuration."
  @spec fresh(
          String.t(),
          String.t(),
          Configuration.t(),
          String.t(),
          Dependencies.t()
        ) :: result()
  def fresh(identifier, label, configuration, workspace, dependencies) do
    with {:ok, selection} <- select_provider(configuration, dependencies),
         {:ok, state} <-
           build_state(identifier, label, selection.model, configuration, workspace) do
      {:ok, state, configuration}
    end
  end

  defp load(invocation, dependencies) do
    case Loader.load(invocation, dependencies.system) do
      {:ok, configuration, workspace} -> {:ok, configuration, workspace}
      {:error, error} -> {:error, :configuration, error}
    end
  end

  defp select_provider(configuration, dependencies) do
    case Provider.build(configuration, dependencies.task.provider) do
      {:ok, selection} -> {:ok, selection}
      {:error, error} -> {:error, :provider, error}
    end
  end

  defp prepare_selected(
         invocation,
         base_configuration,
         bound_configuration,
         workspace,
         identifier,
         label,
         dependencies
       ) do
    with {:ok, selection} <- select_provider(bound_configuration, dependencies),
         {:ok, state} <-
           build_state(identifier, label, selection.model, bound_configuration, workspace) do
      {:ok, loaded_state(state, invocation), base_configuration}
    end
  end

  defp session_identifier(%Invocation{resume: identifier}, _dependencies)
       when is_binary(identifier) do
    identifier_result(Identifier.new(identifier))
  end

  defp session_identifier(%Invocation{session: identifier}, _dependencies)
       when is_binary(identifier) do
    identifier_result(Identifier.new(identifier))
  end

  defp session_identifier(%Invocation{}, %Dependencies{task: task_dependencies}) do
    case task_dependencies.identifier.() do
      {:ok, identifier} -> identifier_result(Identifier.new(identifier))
      _result -> {:error, :session, :identifier_unavailable}
    end
  end

  defp identifier_result({:ok, identifier}) do
    {:ok, identifier}
  end

  defp identifier_result({:error, error}) do
    {:error, :session, error}
  end

  defp build_state(identifier, label, model, configuration, workspace) do
    attributes = [
      session_id: identifier,
      session_label: label || identifier,
      provider: Atom.to_string(configuration.provider),
      model: model,
      workspace: workspace,
      web: configuration.web
    ]

    case State.new(attributes) do
      {:ok, state} -> {:ok, state}
      {:error, error} -> {:error, :internal, error}
    end
  end

  defp loaded_state(state, %Invocation{resume: identifier}) when is_binary(identifier) do
    State.persisted(state)
  end

  defp loaded_state(state, %Invocation{}) do
    state
  end
end
