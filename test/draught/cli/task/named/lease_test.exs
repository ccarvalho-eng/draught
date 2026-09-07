defmodule Draught.CLI.Task.Named.LeaseTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store
  alias Draught.CLI.Task.Named.Lease

  @moduletag :tmp_dir

  test "preserves unknown publication state without attempting destructive cleanup", %{
    tmp_dir: root
  } do
    workspace = Path.join(root, "workspace")
    File.mkdir!(workspace)
    environment = %{"XDG_STATE_HOME" => Path.join(root, "state")}
    assert {:ok, store} = Store.initialize(workspace, "session-01", environment)
    File.write!(store.paths.binding, "published")

    error = Failure.publication_unknown()
    assert {:error, :session, ^error} = Lease.abort(store, error)
    assert File.exists?(store.paths.binding)
    assert :ok = Store.close(store)
  end
end
