defmodule Draught.CLI.Session.Store.LeaseTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Store.Lease
  alias Draught.CLI.Session.Store.Lease.Endpoint
  alias Draught.CLI.Session.Store.Lease.Probe
  alias Draught.CLI.Session.Store.Local
  alias Draught.CLI.Session.Store.Paths

  @receive_timeout 2_000
  @moduletag :tmp_dir

  test "admits one owner and releases ownership explicitly", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)

    assert {:ok, lease} = Lease.acquire(paths)
    assert {:error, locked} = Lease.acquire(paths)
    assert locked.code == "session_locked"

    assert :ok = Lease.release(lease)
    assert {:ok, next_lease} = Lease.acquire(paths)
    assert :ok = Lease.release(next_lease)
  end

  test "releases the kernel lease when the acquiring process exits", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    parent = self()

    caller =
      spawn(fn ->
        assert {:ok, _lease} = Lease.acquire(paths)
        send(parent, :lease_acquired)

        receive do
          :finish -> :ok
        end
      end)

    assert_receive :lease_acquired, @receive_timeout
    assert {:error, %{code: "session_locked"}} = Lease.acquire(paths)

    Process.exit(caller, :kill)
    assert eventually_acquired(paths)
  end

  test "releases the kernel lease when its owner is killed", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    {caller, lease} = caller_holding(paths)
    caller_monitor = Process.monitor(caller)
    Process.exit(lease.owner, :kill)

    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, reason}, @receive_timeout
    assert reason in [:killed, :noproc]
    assert eventually_acquired(paths)
  end

  test "fails the whole lease when an identity responder exits", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    {caller, lease} = caller_holding(paths)
    caller_monitor = Process.monitor(caller)
    owner_state = :sys.get_state(lease.owner)
    entry = List.first(owner_state.listener.entries)

    Process.exit(entry.acceptor, :kill)

    assert_receive {:DOWN, ^caller_monitor, :process, ^caller, _reason}, @receive_timeout
    assert eventually_acquired(paths)
  end

  test "requires a strict endpoint majority after different-session collisions", %{
    tmp_dir: tmp_dir
  } do
    paths = prepared_paths(tmp_dir)
    {key, responders} = different_session_responders(4)

    on_exit(fn -> close_responders(responders) end)

    assert {:error, %{code: "session_storage_unavailable"}} =
             Lease.acquire(%{paths | key: key})
  end

  test "rejects ownership from a separate operating-system process", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    assert {:ok, lease} = Lease.acquire(paths)

    assert {"locked\n", 0} = child_attempt(tmp_dir)
    assert :ok = Lease.release(lease)
  end

  test "state-root aliases cannot acquire the same session concurrently", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    state_alias = Path.join(tmp_dir, "state-alias")
    File.mkdir_p!(workspace)
    File.mkdir_p!(state_home)
    File.ln_s!(state_home, state_alias)

    assert {:ok, direct_paths} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})

    assert {:ok, alias_paths} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_alias})

    assert :ok = Local.prepare(direct_paths)
    assert {:ok, lease} = Lease.acquire(direct_paths)
    assert {:error, %{code: "session_locked"}} = Lease.acquire(alias_paths)
    assert :ok = Lease.release(lease)
  end

  test "recovers immediately after an owning BEAM process exits", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    child = child_owner(tmp_dir)

    assert {:error, %{code: "session_locked"}} = Lease.acquire(paths)
    terminate_child(child)
    assert eventually_acquired(paths)
  end

  test "distinguishes different sessions whose first port candidate collides", %{
    tmp_dir: tmp_dir
  } do
    paths = prepared_paths(tmp_dir)
    {first_key, second_key} = colliding_keys()

    assert {:ok, first} = Lease.acquire(%{paths | key: first_key})
    assert {:ok, second} = Lease.acquire(%{paths | key: second_key})
    assert :ok = Lease.release(second)
    assert :ok = Lease.release(first)
  end

  test "an earlier colliding port becoming free cannot split one session", %{tmp_dir: tmp_dir} do
    paths = prepared_paths(tmp_dir)
    {first_key, second_key} = colliding_keys()

    assert {:ok, blocker} = Lease.acquire(%{paths | key: first_key})
    assert {:ok, existing} = Lease.acquire(%{paths | key: second_key})
    assert :ok = Lease.release(blocker)

    assert {:error, %{code: "session_locked"}} =
             Lease.acquire(%{paths | key: second_key})

    assert :ok = Lease.release(existing)
  end

  defp prepared_paths(tmp_dir) do
    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)
    assert {:ok, paths} = Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})
    assert :ok = Local.prepare(paths)
    paths
  end

  defp eventually_acquired(paths, attempts \\ 50)

  defp eventually_acquired(_paths, 0) do
    false
  end

  defp eventually_acquired(paths, attempts) do
    case Lease.acquire(paths) do
      {:ok, lease} ->
        Lease.release(lease) == :ok

      {:error, _error} ->
        Process.sleep(10)
        eventually_acquired(paths, attempts - 1)
    end
  end

  defp caller_holding(paths) do
    parent = self()

    caller =
      spawn(fn ->
        assert {:ok, lease} = Lease.acquire(paths)
        send(parent, {:lease_acquired, self(), lease})
        Process.sleep(:infinity)
      end)

    assert_receive {:lease_acquired, ^caller, lease}, @receive_timeout
    {caller, lease}
  end

  defp different_session_responders(count, attempt \\ 0) do
    key = key("quorum-#{attempt}")

    ports =
      key
      |> Endpoint.candidates()
      |> Enum.take(count)

    case open_responders(ports, []) do
      {:ok, responders} -> {key, responders}
      :retry -> different_session_responders(count, attempt + 1)
    end
  end

  defp open_responders([], responders) do
    {:ok, responders}
  end

  defp open_responders([port | remaining], responders) do
    case :gen_tcp.listen(port, listener_options()) do
      {:ok, socket} ->
        acceptor = spawn(fn -> respond_different(socket) end)
        open_responders(remaining, [%{acceptor: acceptor, socket: socket} | responders])

      {:error, _reason} ->
        close_responders(responders)
        :retry
    end
  end

  defp respond_different(listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        respond_different_to(socket)
        respond_different(listener)

      {:error, _reason} ->
        :ok
    end
  end

  defp respond_different_to(socket) do
    other_key = String.duplicate("f", 64)

    case :gen_tcp.recv(socket, 0, @receive_timeout) do
      {:ok, request} -> Probe.respond(socket, request, other_key)
      {:error, _reason} -> :ok
    end

    :gen_tcp.close(socket)
  end

  defp close_responders(responders) do
    Enum.each(responders, fn responder ->
      :gen_tcp.close(responder.socket)
      Process.exit(responder.acceptor, :shutdown)
    end)
  end

  defp listener_options do
    [
      :binary,
      active: false,
      ip: {127, 0, 0, 1},
      packet: 4,
      packet_size: 256,
      reuseaddr: true
    ]
  end

  defp child_attempt(tmp_dir) do
    mix = System.find_executable("mix")
    {workspace, state_home} = child_paths(tmp_dir)
    script = child_script("attempt")

    System.cmd(
      mix,
      ["run", "--no-compile", "--no-deps-check", "-e", script, "--", workspace, state_home],
      env: child_command_environment(),
      stderr_to_stdout: true
    )
  end

  defp child_owner(tmp_dir) do
    mix = System.find_executable("mix")
    {workspace, state_home} = child_paths(tmp_dir)
    script = child_script("hold")

    port =
      Port.open(
        {:spawn_executable, mix},
        [
          :binary,
          :exit_status,
          args: [
            "run",
            "--no-compile",
            "--no-deps-check",
            "-e",
            script,
            "--",
            workspace,
            state_home
          ],
          env: child_port_environment()
        ]
      )

    on_exit(fn -> terminate_child_if_running(port) end)
    assert_receive {^port, {:data, "acquired\n"}}, @receive_timeout
    port
  end

  defp child_script(mode) do
    """
    Application.ensure_all_started(:draught)
    [workspace, state_home] = System.argv()
    {:ok, paths} = Draught.CLI.Session.Store.Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})
    :ok = Draught.CLI.Session.Store.Local.prepare(paths)
    case {#{inspect(mode)}, Draught.CLI.Session.Store.Lease.acquire(paths)} do
      {"attempt", {:error, %{code: "session_locked"}}} -> IO.puts("locked")
      {"hold", {:ok, _lease}} -> IO.puts("acquired"); Process.sleep(:infinity)
      {_mode, {:ok, lease}} -> Draught.CLI.Session.Store.Lease.release(lease); System.halt(9)
      _result -> System.halt(10)
    end
    """
  end

  defp child_paths(tmp_dir) do
    {Path.join(tmp_dir, "workspace"), Path.join(tmp_dir, "state")}
  end

  defp child_command_environment do
    [
      {"HOME", System.get_env("HOME")},
      {"MIX_ENV", "test"},
      {"PATH", System.get_env("PATH")}
    ]
  end

  defp child_port_environment do
    Enum.map(child_command_environment(), fn {key, value} ->
      {String.to_charlist(key), String.to_charlist(value)}
    end)
  end

  defp terminate_child(port) do
    assert {:os_pid, pid} = Port.info(port, :os_pid)
    assert :ok = kill_child(pid)

    assert_receive {^port, {:exit_status, _status}}, @receive_timeout
  end

  defp terminate_child_if_running(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> kill_child(pid)
      nil -> :ok
    end
  end

  defp kill_child(pid) do
    executable = System.find_executable("kill")

    case System.cmd(executable, ["-KILL", Integer.to_string(pid)],
           env: [{"PATH", System.get_env("PATH")}],
           stderr_to_stdout: true
         ) do
      {"", 0} -> :ok
      {_output, _status} -> :error
    end
  end

  defp colliding_keys do
    1..1_000
    |> Enum.map(&key/1)
    |> Enum.group_by(&first_candidate/1)
    |> Enum.find_value(fn
      {_port, [first, second | _remaining]} -> {first, second}
      {_port, _keys} -> nil
    end)
  end

  defp key(value) do
    :sha256
    |> :crypto.hash(to_string(value))
    |> Base.encode16(case: :lower)
  end

  defp first_candidate(key) do
    key
    |> Endpoint.candidates()
    |> List.first()
  end
end
