defmodule Draught.Skill.Repository.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Catalog
  alias Draught.Skill.Definition
  alias Draught.Skill.Metadata
  alias Draught.Skill.Repository.Local

  defmodule Builtin do
    @moduledoc false

    @metadata %Metadata{name: "testing", description: "Built-in testing", origin: :builtin}

    @spec list(String.t(), map(), term()) :: {:ok, Catalog.t()}
    def list(_workspace, _environment, _configuration) do
      {:ok, Catalog.new([@metadata], 0)}
    end

    @spec fetch(String.t(), String.t(), map(), term()) ::
            {:ok, Definition.t()} | {:error, :not_found}
    def fetch("testing", _workspace, _environment, _configuration) do
      {:ok,
       %Definition{
         name: "testing",
         description: "Built-in testing",
         instructions: "Run focused tests",
         origin: :builtin
       }}
    end

    @spec fetch(String.t(), String.t(), map(), term()) ::
            {:ok, Definition.t()} | {:error, :not_found}
    def fetch(_name, _workspace, _environment, _configuration) do
      {:error, :not_found}
    end
  end

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

  @tag :tmp_dir
  test "loads built-ins last and includes their bounded Markdown references", %{tmp_dir: root} do
    workspace = Path.join(root, "workspace")
    builtins = Path.join(root, "builtins")

    write_skill(builtins, "review", "Built-in review", "Built-in instructions")
    write_reference(builtins, "review", "checklist.md", "Inspect the complete diff.")
    write_skill(builtins, "testing", "Built-in testing", "Run focused tests")

    write_skill(
      Path.join([workspace, ".draught", "skills"]),
      "review",
      "Workspace review",
      "Workspace instructions"
    )

    configuration = %{builtin_root: builtins}

    assert {:ok, catalog} = Local.list(workspace, %{}, configuration)

    assert Enum.map(catalog.entries, &{&1.name, &1.origin}) ==
             [{"review", :workspace_draught}, {"testing", :builtin}]

    assert {:ok, review} = Local.fetch("review", workspace, %{}, configuration)
    assert review.instructions == "Workspace instructions"

    assert {:ok, testing} = Local.fetch("testing", workspace, %{}, configuration)
    assert testing.instructions == "Run focused tests"

    write_reference(builtins, "testing", "verification.md", "Check the result.")

    assert {:ok, testing_with_reference} =
             Local.fetch("testing", workspace, %{}, configuration)

    assert testing_with_reference.instructions =~ "Bundled reference: references/verification.md"
    assert testing_with_reference.instructions =~ "Check the result."
  end

  @tag :tmp_dir
  test "delegates to an embedded built-in repository after local roots", %{tmp_dir: root} do
    workspace = Path.join(root, "workspace")

    write_skill(
      Path.join([workspace, ".draught", "skills"]),
      "review",
      "Workspace review",
      "Workspace instructions"
    )

    configuration = %{builtin_repository: {Builtin, nil}}

    assert {:ok, catalog} = Local.list(workspace, %{}, configuration)

    assert Enum.map(catalog.entries, &{&1.name, &1.origin}) ==
             [{"review", :workspace_draught}, {"testing", :builtin}]

    assert {:ok, testing} = Local.fetch("testing", workspace, %{}, configuration)
    assert testing.instructions == "Run focused tests"
  end

  defp write_skill(root, name, description, instructions) do
    directory = Path.join(root, name)
    File.mkdir_p!(directory)

    directory
    |> Path.join("SKILL.md")
    |> File.write!(skill(name, description, instructions))
  end

  defp write_reference(root, name, filename, content) do
    references = Path.join([root, name, "references"])
    File.mkdir_p!(references)

    references
    |> Path.join(filename)
    |> File.write!(content)
  end

  defp skill(name, description, instructions) do
    "---\nname: #{name}\ndescription: #{description}\n---\n#{instructions}"
  end
end
