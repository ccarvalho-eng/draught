defmodule Draught.CLI.Interactive.Skill.CommandTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Skill.Command
  alias Draught.CLI.Interactive.State
  alias Draught.Skill.Catalog
  alias Draught.Skill.Definition
  alias Draught.Skill.Metadata

  defmodule Repository do
    @behaviour Draught.Skill.Repository.Adapter

    @impl Draught.Skill.Repository.Adapter
    def list(_workspace, _environment, configuration) do
      configuration.list
    end

    @impl Draught.Skill.Repository.Adapter
    def fetch(name, _workspace, _environment, configuration) do
      send(configuration.owner, {:skill_fetch, name})
      configuration.fetch
    end
  end

  test "lists bounded metadata without fetching instruction bodies" do
    metadata = %Metadata{
      description: "Review changes",
      name: "review",
      origin: :workspace_draught
    }

    dependencies = dependencies(list: {:ok, Catalog.new([metadata], 1)})

    assert Command.run(:skills, nil, state(), dependencies) ==
             {:ok, {:catalog, Catalog.new([metadata], 1)}}

    refute_receive {:skill_fetch, _name}
  end

  test "loads and frames only the explicitly selected skill" do
    definition = %Definition{
      description: "Review changes",
      instructions: "Inspect the complete diff.",
      name: "review",
      origin: :workspace_draught
    }

    dependencies = dependencies(fetch: {:ok, definition})

    assert {:ok, {:invoke, "review", prompt}} =
             Command.run(:skill, "review", state(), dependencies)

    assert prompt =~ ~s("instructions":"Inspect the complete diff.")
    assert_receive {:skill_fetch, "review"}
  end

  test "returns recoverable errors for unavailable skills" do
    dependencies = dependencies(fetch: {:error, :not_found})

    assert Command.run(:skill, "missing", state(), dependencies) ==
             {:error, :not_found}
  end

  defp dependencies(options) do
    configuration = %{
      fetch: Keyword.get(options, :fetch, {:error, :not_found}),
      list: Keyword.get(options, :list, {:ok, Catalog.new([], 0)}),
      owner: self()
    }

    {:ok, dependencies} =
      Dependencies.new(skill_repository: {Repository, configuration})

    dependencies
  end

  defp state do
    {:ok, state} =
      State.new(
        session_id: "session-01",
        provider: "ollama",
        model: "qwen3",
        workspace: "/workspace",
        web: false
      )

    state
  end
end
