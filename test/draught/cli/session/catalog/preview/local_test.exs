defmodule Draught.CLI.Session.Catalog.Preview.LocalTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Catalog.Preview.Local
  alias Draught.CLI.Session.Store

  @moduletag :tmp_dir

  test "replaces an owner-only preview and rejects a mismatched immutable ID", %{tmp_dir: root} do
    {store, paths} = store(root)
    assert {:ok, first} = Preview.new("session-01", "Inspect")
    assert {:ok, second} = Preview.new("session-01", "Continue")

    assert :ok = Local.put(paths, first)
    assert :ok = Local.put(paths, second)
    assert {:ok, ^second} = Local.read(paths)
    assert {:ok, %File.Stat{type: :regular, mode: mode}} = File.lstat(paths.preview)
    assert band(mode, 0o777) == 0o600

    assert {:ok, mismatched} = Preview.new("other-session", "Unsafe")
    assert {:error, error} = Local.put(paths, mismatched)
    assert error.code == "session_preview_invalid"
    assert {:ok, ^second} = Local.read(paths)
    assert :ok = Store.close(store)
  end

  test "returns no preview when absent and fails closed for a symlink", %{tmp_dir: root} do
    {store, paths} = store(root)
    assert {:ok, nil} = Local.read(paths)

    target = Path.join(root, "target.json")
    File.write!(target, "{}")
    File.ln_s!(target, paths.preview)

    assert {:error, error} = Local.read(paths)
    assert error.code == "session_preview_invalid"
    assert :ok = Store.close(store)
  end

  defp store(root) do
    workspace = Path.join(root, "workspace")
    File.mkdir_p!(workspace)
    environment = %{"XDG_STATE_HOME" => Path.join(root, "state")}
    assert {:ok, store} = Store.initialize(workspace, "session-01", environment)
    {store, store.paths}
  end
end
