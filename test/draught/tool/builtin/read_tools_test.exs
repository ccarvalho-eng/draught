defmodule Draught.Tool.Builtin.ReadToolsTest do
  use ExUnit.Case, async: true

  alias Draught.Tool
  alias Draught.Tool.Builtin.ListDirectory
  alias Draught.Tool.Builtin.ReadFile
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  @moduletag :tmp_dir

  test "reads one confined file with bounded content", %{tmp_dir: workspace} do
    path = Path.join(workspace, "README.md")
    File.write!(path, "contents")

    assert {:ok, registry} = registry([ReadFile])

    assert {:ok, result} =
             Tool.execute(
               registry,
               call("read_file", %{"path" => "README.md"}),
               context(workspace)
             )

    assert result.status == :success
    assert result.content == "contents"

    assert {:ok, bounded_result} =
             Tool.execute(
               registry,
               call("read_file", %{"path" => "README.md"}),
               context(workspace, max_output_bytes: 4)
             )

    assert bounded_result.status == :error
    assert bounded_result.error.code == "file_too_large"
  end

  test "rejects read traversal and symlink escapes", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    outside = Path.join(tmp_dir, "outside")
    secret = Path.join(outside, "secret.txt")
    escape = Path.join(workspace, "escape")
    File.mkdir_p!(workspace)
    File.mkdir_p!(outside)
    File.write!(secret, "secret")
    File.ln_s!(outside, escape)

    assert {:ok, registry} = registry([ReadFile])

    for path <- ["../outside/secret.txt", "escape/secret.txt"] do
      assert {:ok, result} =
               Tool.execute(registry, call("read_file", %{"path" => path}), context(workspace))

      assert result.status == :error
      assert result.error.code == "invalid_path"
    end
  end

  test "lists one confined directory in stable order", %{tmp_dir: workspace} do
    library = Path.join(workspace, "lib")
    last = Path.join(workspace, "z.txt")
    first = Path.join(workspace, "a.txt")
    File.mkdir_p!(library)
    File.write!(last, "z")
    File.write!(first, "a")

    assert {:ok, registry} = registry([ListDirectory])

    assert {:ok, result} =
             Tool.execute(
               registry,
               call("list_directory", %{"path" => "."}),
               context(workspace)
             )

    assert result.status == :success
    assert result.content == "a.txt\nlib\nz.txt"
  end

  test "returns structured errors for missing files and nondirectories", %{tmp_dir: workspace} do
    file = Path.join(workspace, "file.txt")
    File.write!(file, "content")
    assert {:ok, registry} = registry([ReadFile, ListDirectory])

    assert {:ok, missing} =
             Tool.execute(
               registry,
               call("read_file", %{"path" => "missing.txt"}),
               context(workspace)
             )

    assert missing.error.code == "invalid_path"

    assert {:ok, not_directory} =
             Tool.execute(
               registry,
               call("list_directory", %{"path" => "file.txt"}),
               context(workspace)
             )

    assert not_directory.error.code == "list_failed"
  end

  defp registry(modules) do
    with definitions <- Enum.map(modules, &definition!/1) do
      Registry.new(definitions)
    end
  end

  defp definition!(module) do
    {:ok, definition} = module.definition()
    definition
  end

  defp context(workspace, options \\ []) do
    {:ok, policy} =
      options
      |> Keyword.put(:allowed_risks, [:read])
      |> Policy.new()

    {:ok, context} = Context.new(workspace: workspace, policy: policy)
    context
  end

  defp call(name, arguments) do
    %{id: "call-1", name: name, arguments: arguments}
  end
end
