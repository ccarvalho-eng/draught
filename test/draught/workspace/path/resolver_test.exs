defmodule Draught.Workspace.Path.ResolverTest do
  use ExUnit.Case, async: true

  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Resolver

  @moduletag :tmp_dir

  test "resolves existing nested reads and nonexistent nested writes", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    existing = Path.join(workspace, "lib/example.ex")
    write_target = Path.join(workspace, "generated/deep/result.txt")

    existing
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(existing, "content")

    assert {:ok, ^existing} = Resolver.resolve(workspace, "lib/example.ex", :read)
    assert {:ok, ^write_target} = Resolver.resolve(workspace, "generated/deep/result.txt", :write)
    assert {:error, %Error{}} = Resolver.resolve(workspace, "missing.txt", :read)
  end

  test "resolves nested symlinks that remain inside the workspace", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    target = Path.join(workspace, "real/example.ex")
    write_target = Path.join(workspace, "real/generated/result.txt")

    target
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(target, "content")
    File.ln_s!("real", Path.join(workspace, "second"))
    File.ln_s!("second", Path.join(workspace, "first"))

    assert {:ok, ^target} = Resolver.resolve(workspace, "first/example.ex", :read)

    assert {:ok, ^write_target} =
             Resolver.resolve(workspace, "first/generated/result.txt", :write)
  end

  test "uses the physical directory as the root when the workspace is a symlink", %{
    tmp_dir: tmp_dir
  } do
    physical_workspace = Path.join(tmp_dir, "physical")
    workspace_link = Path.join(tmp_dir, "workspace")
    target = Path.join(physical_workspace, "README.md")

    File.mkdir_p!(physical_workspace)
    File.write!(target, "content")
    File.ln_s!(physical_workspace, workspace_link)

    assert {:ok, ^target} = Resolver.resolve(workspace_link, "README.md", :read)
  end

  test "rejects existing symlink escapes and sibling-prefix targets", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    sibling = Path.join(tmp_dir, "workspace-sibling")
    secret = Path.join(sibling, "secret.txt")

    File.mkdir_p!(workspace)
    File.mkdir_p!(sibling)
    File.write!(secret, "secret")
    File.ln_s!(sibling, Path.join(workspace, "escape"))

    assert {:error, %Error{}} = Resolver.resolve(workspace, "escape/secret.txt", :read)
    assert {:error, %Error{}} = Resolver.resolve(workspace, "escape/new.txt", :write)
  end

  test "rejects broken and cyclic symlinks for reads and writes", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(workspace)
    File.ln_s!("missing", Path.join(workspace, "broken"))
    File.ln_s!("cycle-b", Path.join(workspace, "cycle-a"))
    File.ln_s!("cycle-a", Path.join(workspace, "cycle-b"))

    for {path, access} <- [
          {"broken", :read},
          {"broken/new.txt", :write},
          {"cycle-a", :read},
          {"cycle-a/new.txt", :write}
        ] do
      assert {:error, %Error{}} = Resolver.resolve(workspace, path, access)
    end
  end

  test "requires an existing directory workspace and a supported access mode", %{tmp_dir: tmp_dir} do
    file = Path.join(tmp_dir, "file")
    missing = Path.join(tmp_dir, "missing")
    File.write!(file, "content")

    assert {:error, %Error{}} = Resolver.resolve(missing, "file", :read)
    assert {:error, %Error{}} = Resolver.resolve(file, "child", :read)
    assert {:error, %Error{}} = Resolver.resolve(tmp_dir, "file", :unknown)
  end
end
