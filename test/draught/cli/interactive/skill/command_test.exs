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
      send(configuration.owner, :skill_list)
      configuration.list
    end

    @impl Draught.Skill.Repository.Adapter
    def fetch(name, _workspace, _environment, configuration) do
      send(configuration.owner, {:skill_fetch, name})

      case configuration.fetch do
        fetches when is_map(fetches) -> Map.get(fetches, name, {:error, :not_found})
        result -> result
      end
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

  test "passes bounded trailing arguments to the selected skill" do
    definition = %Definition{
      description: "Review changes",
      instructions: "Inspect $ARGUMENTS.",
      name: "review",
      origin: :builtin
    }

    dependencies = dependencies(fetch: {:ok, definition})

    assert {:ok, {:invoke, "review", prompt}} =
             Command.run(:skill, "review lib/draught.ex", state(), dependencies)

    assert prompt =~ ~s("arguments":"lib/draught.ex")
    assert_receive {:skill_fetch, "review"}
  end

  test "returns recoverable errors for unavailable skills" do
    dependencies = dependencies(fetch: {:error, :not_found})

    assert Command.run(:skill, "missing", state(), dependencies) ==
             {:error, :not_found}
  end

  test "selects a listed skill by its one-based position" do
    first = definition("review", "Review changes")
    second = definition("testing", "Run focused tests")

    dependencies =
      dependencies(
        list: {:ok, Catalog.new([metadata(first), metadata(second)], 0)},
        fetch: %{
          "review" => {:ok, first},
          "testing" => {:ok, second}
        }
      )

    assert {:ok, {:invoke, "testing", prompt}} =
             Command.run(:skill, "2", state(), dependencies)

    assert prompt =~ ~s("instructions":"Run focused tests")
    assert_receive {:skill_fetch, "2"}
    assert_receive :skill_list
    assert_receive {:skill_fetch, "testing"}
  end

  test "prefers an exact numeric skill name over the matching position" do
    numeric = definition("2", "Use the numeric skill")
    second = definition("testing", "Run focused tests")

    dependencies =
      dependencies(
        list: {:ok, Catalog.new([metadata(numeric), metadata(second)], 0)},
        fetch: %{"2" => {:ok, numeric}, "testing" => {:ok, second}}
      )

    assert {:ok, {:invoke, "2", prompt}} =
             Command.run(:skill, "2", state(), dependencies)

    assert prompt =~ ~s("instructions":"Use the numeric skill")
    assert_receive {:skill_fetch, "2"}
    refute_receive {:skill_fetch, "testing"}
  end

  test "rejects noncanonical or unavailable positions without selecting another skill" do
    review = definition("review", "Review changes")

    dependencies =
      dependencies(
        list: {:ok, Catalog.new([metadata(review)], 0)},
        fetch: %{"review" => {:ok, review}}
      )

    assert Command.run(:skill, "0", state(), dependencies) == {:error, :not_found}
    assert Command.run(:skill, "01", state(), dependencies) == {:error, :not_found}
    assert Command.run(:skill, "2", state(), dependencies) == {:error, :not_found}

    assert_receive :skill_list
  end

  test "does not enumerate the catalog for a missing exact name" do
    dependencies = dependencies(fetch: %{})

    assert Command.run(:skill, "missing", state(), dependencies) ==
             {:error, :not_found}

    refute_receive :skill_list
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

  defp definition(name, instructions) do
    %Definition{
      description: "Skill #{name}",
      instructions: instructions,
      name: name,
      origin: :workspace_draught
    }
  end

  defp metadata(%Definition{} = definition) do
    %Metadata{
      description: definition.description,
      name: definition.name,
      origin: definition.origin
    }
  end
end
