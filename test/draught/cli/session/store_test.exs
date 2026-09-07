defmodule Draught.CLI.Session.StoreTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Store

  @moduletag :tmp_dir

  test "creates a session while retaining exclusive ownership", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)

    assert {:ok, handle} = Store.open(:create, workspace, "review", environment)
    assert handle.mode == :create
    assert File.dir?(handle.paths.session)

    assert {:error, %{code: "session_locked"}} =
             Store.open(:create, workspace, "review", environment)

    assert :ok = Store.close(handle)

    assert {:error, %{code: "session_already_exists"}} =
             Store.open(:create, workspace, "review", environment)
  end

  test "a missing resume releases ownership before returning", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)

    assert {:error, %{code: "session_not_found"}} =
             Store.open(:resume, workspace, "review", environment)

    assert {:ok, handle} = Store.open(:create, workspace, "review", environment)
    assert :ok = Store.close(handle)
  end

  test "an existing create releases ownership before returning", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)
    assert {:ok, created} = Store.open(:create, workspace, "review", environment)
    assert :ok = Store.close(created)
    assert :ok = Store.close(created)

    assert {:error, %{code: "session_already_exists"}} =
             Store.open(:create, workspace, "review", environment)

    assert {:ok, resumed} = Store.open(:resume, workspace, "review", environment)
    assert resumed.mode == :resume
    assert :ok = Store.close(resumed)
  end

  test "initialization recovers an interrupted marker-only session", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)
    assert {:ok, interrupted} = Store.open(:create, workspace, "review", environment)
    assert :ok = Store.close(interrupted)

    assert {:ok, recovered} = Store.initialize(workspace, "review", environment)
    assert recovered.mode == :create
    assert File.dir?(recovered.paths.session)
    assert :ok = Store.close(recovered)
  end

  test "close is safe after the lease owner has already exited", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)
    Process.flag(:trap_exit, true)
    assert {:ok, handle} = Store.open(:create, workspace, "review", environment)
    Process.exit(handle.lease.owner, :kill)

    assert_receive {:EXIT, owner, :killed}
    assert owner == handle.lease.owner
    assert :ok = Store.close(handle)
  end

  test "validates inputs before creating state", %{tmp_dir: tmp_dir} do
    {workspace, environment} = scope(tmp_dir)

    assert {:error, mode_error} = Store.open(:replace, workspace, "review", environment)
    assert [%{path: [:mode]}] = mode_error.violations

    assert {:error, environment_error} = Store.open(:create, workspace, "review", [])
    assert [%{path: [:environment]}] = environment_error.violations

    assert {:error, error} = Store.open(:create, workspace, "../escape", environment)
    assert [%{path: [:session_id]}] = error.violations
    refute File.exists?(environment["XDG_STATE_HOME"])
  end

  defp scope(tmp_dir) do
    workspace = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(workspace)
    {workspace, %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}}
  end
end
