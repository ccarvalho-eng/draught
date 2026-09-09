defmodule Draught.Skill.Repository.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Repository.Local

  @tag :tmp_dir
  test "discovers bounded metadata with deterministic root precedence", %{tmp_dir: root} do
    workspace = Path.join(root, "workspace")
    config = Path.join(root, "config")
    agents = Path.join(root, "agents")

    write_skill(
      Path.join([config, "draught", "skills"]),
      "review",
      "User review",
      "User instructions"
    )

    write_skill(
      Path.join([workspace, ".agents", "skills"]),
      "review",
      "Shared review",
      "Shared instructions"
    )

    write_skill(
      Path.join([workspace, ".draught", "skills"]),
      "review",
      "Workspace review",
      "Workspace instructions"
    )

    write_skill(
      Path.join([agents, "skills"]),
      "security",
      "Security review",
      "Security instructions"
    )

    environment = %{"XDG_CONFIG_HOME" => config, "AGENTS_HOME" => agents}

    assert {:ok, catalog} = Local.list(workspace, environment, nil)
    assert Enum.map(catalog.entries, & &1.name) == ["review", "security"]

    assert [review, security] = catalog.entries
    assert review.description == "Workspace review"
    assert review.origin == :workspace_draught
    assert security.origin == :user_agents
    refute Map.has_key?(review, :instructions)

    assert {:ok, definition} = Local.fetch("review", workspace, environment, nil)
    assert definition.instructions == "Workspace instructions"
    assert definition.origin == :workspace_draught
  end

  @tag :tmp_dir
  test "skips invalid and unsafe entries without failing discovery", %{tmp_dir: root} do
    workspace = Path.join(root, "workspace")
    skills = Path.join([workspace, ".draught", "skills"])
    File.mkdir_p!(skills)

    skills
    |> Path.join("BadName")
    |> File.mkdir_p!()

    bad_skill_file = Path.join([skills, "BadName", "SKILL.md"])
    File.write!(bad_skill_file, "invalid")

    skills
    |> Path.join("plain-file")
    |> File.write!("invalid")

    valid = Path.join(skills, "valid-skill")
    File.mkdir_p!(valid)
    target = Path.join(root, "outside.md")
    File.write!(target, skill("valid-skill", "Unsafe", "Instructions"))

    valid
    |> Path.join("SKILL.md")
    |> then(&File.ln_s!(target, &1))

    assert {:ok, catalog} = Local.list(workspace, %{}, nil)
    assert catalog.entries == []
    assert catalog.rejected == 3
    assert Local.fetch("valid-skill", workspace, %{}, nil) == {:error, :not_found}
  end

  @tag :tmp_dir
  test "rejects oversized skill files before loading their body", %{tmp_dir: root} do
    workspace = Path.join(root, "workspace")
    skills = Path.join([workspace, ".draught", "skills"])

    oversized =
      Local.maximum_bytes()
      |> Kernel.+(1)
      |> then(&String.duplicate("x", &1))

    write_skill(skills, "large-skill", "Large", oversized)

    assert {:ok, catalog} = Local.list(workspace, %{}, nil)
    assert catalog.entries == []
    assert catalog.rejected == 1
    assert Local.fetch("large-skill", workspace, %{}, nil) == {:error, :not_found}
  end

  defp write_skill(root, name, description, instructions) do
    directory = Path.join(root, name)
    File.mkdir_p!(directory)

    directory
    |> Path.join("SKILL.md")
    |> File.write!(skill(name, description, instructions))
  end

  defp skill(name, description, instructions) do
    "---\nname: #{name}\ndescription: #{description}\n---\n#{instructions}"
  end
end
