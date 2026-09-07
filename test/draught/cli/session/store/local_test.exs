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

  test "recovers an empty directory left by an interrupted create", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    File.mkdir!(paths.session)

    assert {:error, unsafe} = Local.validate(paths)
    assert unsafe.code == "session_storage_unsafe"
    assert :ok = Local.create(paths)
    assert :ok = Local.validate(paths)
    assert File.read!(paths.marker) == "draught-session/v1\n"

    assert {:ok, %File.Stat{mode: mode, type: :regular}} = File.lstat(paths.marker)
    assert Bitwise.band(mode, 0o777) == 0o600
  end

  test "recovers only a strict marker prefix left by an interrupted write", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    File.mkdir!(paths.session)
    File.chmod!(paths.session, 0o700)
    File.write!(paths.marker, "draught-session/")

    assert :ok = Local.create(paths)
    assert :ok = Local.validate(paths)
  end

  test "finishes permissions for a complete marker left before chmod", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    File.mkdir!(paths.session)
    File.chmod!(paths.session, 0o700)
    File.write!(paths.marker, "draught-session/v1\n")
    File.chmod!(paths.marker, 0o644)

    assert :ok = Local.create(paths)
    assert :ok = Local.validate(paths)
    assert {:ok, %File.Stat{mode: mode}} = File.lstat(paths.marker)
    assert Bitwise.band(mode, 0o777) == 0o600
  end

  test "preserves an arbitrary marker-only directory as unsafe", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    File.mkdir!(paths.session)
    File.chmod!(paths.session, 0o700)
    File.write!(paths.marker, "user data")
    File.chmod!(paths.marker, 0o600)

    assert {:error, error} = Local.create(paths)
    assert error.code == "session_storage_unsafe"
    assert File.read!(paths.marker) == "user data"
  end

  test "preserves an oversized marker-only directory as unsafe", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    File.mkdir!(paths.session)
    File.chmod!(paths.session, 0o700)
    contents = "draught-session/v1\nunexpected"
    File.write!(paths.marker, contents)
    File.chmod!(paths.marker, 0o600)

    assert {:error, error} = Local.create(paths)
    assert error.code == "session_storage_unsafe"
    assert File.read!(paths.marker) == contents
  end

  test "preserves a committed marker when its directory becomes unsafe", %{tmp_dir: tmp_dir} do
    paths = paths(tmp_dir)
    assert :ok = Local.prepare(paths)
    assert :ok = Local.create(paths)
    File.chmod!(paths.session, 0o755)

    assert {:error, error} = Local.create(paths)
    assert error.code == "session_storage_unsafe"
    assert File.read!(paths.marker) == "draught-session/v1\n"
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
