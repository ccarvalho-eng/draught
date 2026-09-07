defmodule Draught.CLI.Session.Catalog.Metadata.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Catalog.Metadata
  alias Draught.CLI.Session.Catalog.Metadata.Local
  alias Draught.CLI.Session.Store

  @moduletag :tmp_dir

  test "creates an owner-only record and rejects a mismatched immutable ID", %{tmp_dir: root} do
    {store, paths} = store(root)
    metadata = Metadata.legacy("session-01")
    assert {:ok, renamed} = Metadata.rename(metadata, "Review")

    assert :ok = Local.put(paths, renamed)
    assert {:ok, ^renamed} = Local.read(paths)
    assert {:ok, %File.Stat{type: :regular, mode: mode}} = File.lstat(paths.metadata)
    assert Bitwise.band(mode, 0o777) == 0o600

    mismatched = %{renamed | id: "other-session"}
    assert {:error, error} = Local.put(paths, mismatched)
    assert error.code == "session_metadata_invalid"
    assert {:ok, ^renamed} = Local.read(paths)
    assert :ok = Store.close(store)
  end

  test "fails closed for a symlinked metadata record", %{tmp_dir: root} do
    {store, paths} = store(root)
    target = Path.join(root, "target.json")
    File.write!(target, "{}")
    File.ln_s!(target, paths.metadata)

    assert {:error, error} = Local.read(paths)
    assert error.code == "session_metadata_invalid"
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
