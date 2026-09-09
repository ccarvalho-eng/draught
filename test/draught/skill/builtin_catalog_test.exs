defmodule Draught.Skill.BuiltinCatalogTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Definition
  alias Draught.Skill.Prompt
  alias Draught.Skill.Repository.Local

  @catalog Application.app_dir(:draught, "priv/builtin_skills/catalog")

  test "ships a valid bounded entry document for every built-in skill" do
    entries =
      [@catalog, "*", "SKILL.md"]
      |> Path.join()
      |> Path.wildcard()

    assert Enum.count(entries) == 48

    Enum.each(entries, fn path ->
      directory = Path.dirname(path)
      name = Path.basename(directory)

      assert {:ok, definition} =
               path
               |> File.read!()
               |> Definition.parse(name, :workspace_draught)

      assert definition.name == name
    end)
  end

  test "ships only regular Markdown files in skill directories" do
    files =
      [@catalog, "*", "**", "*.md"]
      |> Path.join()
      |> Path.wildcard()

    assert Enum.count(files) == 148
    assert Enum.all?(files, &File.regular?/1)
    refute Enum.any?(files, &symlink?/1)
  end

  test "loads and frames every built-in skill with its bounded references" do
    configuration = %{builtin_root: @catalog}

    assert {:ok, catalog} = Local.list("/workspace", %{}, configuration)
    assert Enum.count(catalog.entries) == 48
    assert Enum.all?(catalog.entries, &(&1.origin == :builtin))

    Enum.each(catalog.entries, fn metadata ->
      assert {:ok, definition} =
               Local.fetch(metadata.name, "/workspace", %{}, configuration)

      assert {:ok, prompt} = Prompt.render(definition, "focused request")
      assert prompt =~ ~s("arguments":"focused request")
    end)
  end

  defp symlink?(path) do
    match?({:ok, %{type: :symlink}}, File.lstat(path, time: :posix))
  end
end
