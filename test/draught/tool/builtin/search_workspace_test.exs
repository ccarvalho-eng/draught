defmodule Draught.Tool.Builtin.SearchWorkspaceTest do
  use ExUnit.Case, async: true

  alias Draught.Tool
  alias Draught.Tool.Builtin.SearchWorkspace
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  @moduletag :tmp_dir

  test "searches UTF-8 files recursively in stable path and line order", %{tmp_dir: workspace} do
    nested = Path.join(workspace, "lib")
    last = Path.join(workspace, "z.txt")
    first = Path.join(nested, "a.txt")
    File.mkdir_p!(nested)
    File.write!(last, "needle last\n")
    File.write!(first, "first\nneedle nested\nneedle again\n")

    assert {:ok, result} = execute(workspace, %{"query" => "needle"})
    assert result.status == :success

    assert result.content ==
             "lib/a.txt:2:needle nested\nlib/a.txt:3:needle again\nz.txt:1:needle last"
  end

  test "supports case-insensitive search and a confined starting path", %{tmp_dir: workspace} do
    source = Path.join(workspace, "source")
    outside = Path.join(workspace, "outside.txt")
    inside = Path.join(source, "inside.txt")
    File.mkdir_p!(source)
    File.write!(outside, "Needle outside")
    File.write!(inside, "Needle inside")

    assert {:ok, result} =
             execute(workspace, %{
               "query" => "needle",
               "path" => "source",
               "case_sensitive" => false
             })

    assert result.content == "inside.txt:1:Needle inside"
  end

  test "does not follow symlinks or scan excluded generated directories", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    outside = Path.join(tmp_dir, "outside")
    dependencies = Path.join(workspace, "deps")
    secret = Path.join(outside, "secret.txt")
    dependency = Path.join(dependencies, "dependency.txt")
    escape = Path.join(workspace, "escape")
    File.mkdir_p!(workspace)
    File.mkdir_p!(outside)
    File.mkdir_p!(dependencies)
    File.write!(secret, "needle secret")
    File.write!(dependency, "needle dependency")
    File.ln_s!(outside, escape)

    assert {:ok, result} = execute(workspace, %{"query" => "needle"})
    assert result.status == :success
    assert result.content == ""
  end

  test "returns structured errors for invalid queries and paths", %{tmp_dir: workspace} do
    assert {:ok, empty} = execute(workspace, %{"query" => ""})
    assert empty.error.code == "invalid_query"

    assert {:ok, traversal} =
             execute(workspace, %{"query" => "needle", "path" => "../outside"})

    assert traversal.error.code == "invalid_path"
  end

  defp execute(workspace, arguments) do
    {:ok, definition} = SearchWorkspace.definition()
    {:ok, registry} = Registry.new([definition])
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, context} = Context.new(workspace: workspace, policy: policy)

    Tool.execute(
      registry,
      %{id: "call-1", name: "search_workspace", arguments: arguments},
      context
    )
  end
end
