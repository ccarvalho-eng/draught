defmodule Draught.CLI.Interactive.Skill.Command do
  @moduledoc """
  Resolves interactive skill commands through the injected repository boundary.

  Listing returns metadata only. A complete body is fetched and framed only
  when the user selects one exact skill name.
  """

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Skill.Invocation
  alias Draught.CLI.Interactive.Skill.Reference
  alias Draught.CLI.Interactive.State
  alias Draught.Skill.Catalog
  alias Draught.Skill.Name
  alias Draught.Skill.Prompt

  @type result ::
          {:ok, {:catalog, Draught.Skill.Catalog.t()}}
          | {:ok, :index}
          | {:ok, {:invoke, String.t(), String.t()}}
          | {:error, atom()}

  @doc "Lists skills or prepares one explicit invocation without running a provider."
  @spec run(
          :"builtin-skills" | :"custom-skills" | :skill | :skills,
          String.t() | nil,
          State.t(),
          Dependencies.t()
        ) :: result()
  def run(:skills, nil, %State{}, %Dependencies{}) do
    {:ok, :index}
  end

  def run(scope, nil, %State{} = state, %Dependencies{} = dependencies)
      when scope in [:"builtin-skills", :"custom-skills"] do
    case list(state, dependencies) do
      {:ok, catalog} -> {:ok, {:catalog, scope(catalog, scope)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def run(:skill, reference, %State{} = state, %Dependencies{} = dependencies) do
    with {:ok, parsed} <- Invocation.parse(reference),
         {:ok, validated_reference} <- Name.validate(parsed.reference) do
      validated_reference
      |> fetch(state, dependencies)
      |> invocation(validated_reference, parsed.arguments, state, dependencies)
    end
  end

  def run(_command, _argument, %State{}, %Dependencies{}) do
    {:error, :invalid_command}
  end

  defp fetch(name, state, dependencies) do
    {system, system_configuration} = dependencies.system
    {repository, repository_configuration} = dependencies.skill_repository
    environment = system.environment(system_configuration)

    case repository.fetch(name, state.workspace, environment, repository_configuration) do
      {:error, :not_found} ->
        fetch_shorthand(
          name,
          state.workspace,
          environment,
          repository,
          repository_configuration
        )

      result ->
        result
    end
  end

  defp invocation({:ok, definition}, name, arguments, _state, _dependencies) do
    render_invocation(definition, name, arguments)
  end

  defp invocation({:error, :not_found}, reference, arguments, state, dependencies) do
    with {:ok, position} <- Reference.position(reference),
         {:ok, name} <- position_name(position, state, dependencies),
         {:ok, definition} <- fetch(name, state, dependencies) do
      render_invocation(definition, name, arguments)
    end
  end

  defp invocation({:error, reason}, _reference, _arguments, _state, _dependencies) do
    {:error, reason}
  end

  defp render_invocation(definition, name, arguments) do
    case Prompt.render(definition, arguments) do
      {:ok, prompt} -> {:ok, {:invoke, name, prompt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp scope(%Catalog{} = catalog, :"builtin-skills") do
    entries = Enum.filter(catalog.entries, &(&1.origin == :builtin))
    Catalog.new(entries, catalog.rejected)
  end

  defp scope(%Catalog{} = catalog, :"custom-skills") do
    entries = Enum.reject(catalog.entries, &(&1.origin == :builtin))
    Catalog.new(entries, catalog.rejected)
  end

  defp position_name(position, state, dependencies) do
    case State.displayed_skills(state) do
      {:ok, names} -> Reference.name(position, names)
      {:error, :skill_list_required} -> catalog_position_name(position, state, dependencies)
    end
  end

  defp catalog_position_name(position, state, dependencies) do
    with {:ok, catalog} <- list(state, dependencies) do
      Reference.name(position, catalog)
    end
  end

  defp list(state, dependencies) do
    {system, system_configuration} = dependencies.system
    {repository, repository_configuration} = dependencies.skill_repository
    environment = system.environment(system_configuration)
    repository.list(state.workspace, environment, repository_configuration)
  end

  defp fetch_shorthand(name, workspace, environment, repository, configuration) do
    case Name.expand_shorthand(name) do
      {:ok, canonical_name} ->
        repository.fetch(canonical_name, workspace, environment, configuration)

      :error ->
        {:error, :not_found}
    end
  end
end
