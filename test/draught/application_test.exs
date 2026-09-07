defmodule Draught.ApplicationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  test "starts the runtime supervision tree" do
    assert Process.whereis(Draught.Supervisor)
    assert Process.whereis(Draught.Execution.TaskSupervisor)
    assert Process.whereis(Draught.Tool.Mutation.Queue)
    assert Process.whereis(Draught.Session.Supervisor)
    assert Process.whereis(Draught.Session.Registry)
    assert Process.whereis(Draught.Session.DynamicSupervisor)
  end

  test "restarts the session runtime when its registry fails" do
    registry = Process.whereis(Draught.Session.Registry)
    dynamic_supervisor = Process.whereis(Draught.Session.DynamicSupervisor)
    registry_ref = Process.monitor(registry)
    dynamic_supervisor_ref = Process.monitor(dynamic_supervisor)

    capture_log(fn ->
      Supervisor.stop(registry, :registry_failure)
    end)

    assert_receive {:DOWN, ^registry_ref, :process, ^registry, :registry_failure}
    assert_receive {:DOWN, ^dynamic_supervisor_ref, :process, ^dynamic_supervisor, :shutdown}

    new_registry = wait_for_replacement(Draught.Session.Registry, registry)

    new_dynamic_supervisor =
      wait_for_replacement(Draught.Session.DynamicSupervisor, dynamic_supervisor)

    assert is_pid(new_registry)
    assert is_pid(new_dynamic_supervisor)
  end

  defp wait_for_replacement(name, previous_pid, attempts \\ 100)

  defp wait_for_replacement(name, previous_pid, attempts) when attempts > 0 do
    case Process.whereis(name) do
      replacement when is_pid(replacement) and replacement != previous_pid ->
        replacement

      _other ->
        receive do
        after
          10 -> wait_for_replacement(name, previous_pid, attempts - 1)
        end
    end
  end

  defp wait_for_replacement(name, _previous_pid, 0) do
    flunk("#{inspect(name)} was not restarted")
  end
end
