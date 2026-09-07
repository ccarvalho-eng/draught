defmodule Draught.CLI.Session.Store.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Store.Local
  alias Draught.CLI.Session.Store.Paths

  @moduletag :tmp_dir

  test "creates only owner-accessible Draught directories", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)

    assert :ok = Local.prepare(paths)
    assert :ok = Local.create(paths)

    for directory <- [paths.root, paths.workspace, Path.dirname(paths.session), paths.session] do
      assert {:ok, %File.Stat{type: :directory, mode: mode}} = File.lstat(directory)
      assert Bitwise.band(mode, 0o777) == 0o700
    end
  end

  test "keeps create and resume intent explicit", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)

    refute File.exists?(paths.session)
    assert {:error, missing} = Local.validate(paths)
    assert missing.code == "session_not_found"
    refute File.exists?(paths.session)

    assert :ok = Local.create(paths)
    assert :ok = Local.validate(paths)
    assert {:error, exists} = Local.create(paths)
    assert exists.code == "session_already_exists"
  end

  test "rejects a symlinked Draught-owned path", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    target = Path.join(tmp_dir, "target")
    File.mkdir_p!(target)

    paths.root
    |> Path.dirname()
    |> File.mkdir_p!()

    File.ln_s!(target, paths.root)

    assert {:error, error} = Local.prepare(paths)
    assert error.code == "session_storage_unsafe"
  end

  test "does not report an unsafe existing session as a normal conflict", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    target = Path.join(tmp_dir, "target")
    assert :ok = Local.prepare(paths)
    File.mkdir_p!(target)
    File.ln_s!(target, paths.session)

    assert {:error, error} = Local.create(paths)
    assert error.code == "session_storage_unsafe"
  end

  defp paths(tmp_dir) do
    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)
    assert {:ok, paths} = Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})
    paths
  end
end
