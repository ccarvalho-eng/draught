defmodule Draught.CLI.Task.Named.Preview.RecorderTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Catalog.Preview.Local
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store
  alias Draught.CLI.Task.Named.Preview.Recorder
  alias Draught.CLI.Task.Stream

  @moduletag :tmp_dir

  test "does not replace the preview after a failed turn", %{tmp_dir: root} do
    {store, paths} = store(root)
    assert {:ok, preview} = Preview.new("session-01", "Inspect")
    assert :ok = Local.put(paths, preview)

    observation = {{:error, :execution, Failure.storage_unavailable()}, Stream.silent()}

    assert Recorder.record(observation, paths, "Do not save") == observation
    assert {:ok, ^preview} = Local.read(paths)
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
