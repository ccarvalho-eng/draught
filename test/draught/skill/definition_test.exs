defmodule Draught.Skill.DefinitionTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Definition

  test "parses required frontmatter and preserves Markdown instructions" do
    content = """
    ---
    name: safe-migrations
    description: Review migrations for safe rollout behavior
    ---

    # Procedure

    Inspect locks before changing a migration.
    """

    assert {:ok, definition} =
             Definition.parse(content, "safe-migrations", :workspace_draught)

    assert definition.name == "safe-migrations"
    assert definition.description == "Review migrations for safe rollout behavior"
    assert definition.origin == :workspace_draught
    assert definition.instructions =~ "# Procedure"
  end

  test "accepts quoted scalar metadata" do
    content = """
    ---
    name: 'safe-migrations'
    description: "Review: database migrations"
    license: Apache-2.0
    ---
    Follow the procedure.
    """

    assert {:ok, definition} =
             Definition.parse(content, "safe-migrations", :workspace_agents)

    assert definition.name == "safe-migrations"
    assert definition.description == "Review: database migrations"
  end

  test "rejects malformed metadata, name mismatches, and empty instructions" do
    assert Definition.parse("missing frontmatter", "sample", :workspace_draught) ==
             {:error, :invalid_frontmatter}

    mismatch = "---\nname: other\ndescription: Example\n---\nInstructions"

    assert Definition.parse(mismatch, "sample", :workspace_draught) ==
             {:error, :name_mismatch}

    empty = "---\nname: sample\ndescription: Example\n---\n"

    assert Definition.parse(empty, "sample", :workspace_draught) ==
             {:error, :empty_instructions}

    duplicate =
      "---\nname: sample\nname: replacement\ndescription: Example\n---\nInstructions"

    assert Definition.parse(duplicate, "sample", :workspace_draught) ==
             {:error, :invalid_frontmatter}

    unclosed = "---\nname: sample\ndescription: \"Example\n---\nInstructions"

    assert Definition.parse(unclosed, "sample", :workspace_draught) ==
             {:error, :invalid_frontmatter}
  end
end
