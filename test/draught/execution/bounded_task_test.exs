defmodule Draught.Execution.BoundedTaskTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.BoundedTask
  alias Draught.Execution.Runner.Failure.Runtime

  @execution_timeout 500
  @receive_timeout 2_000

  test "returns the effect result while its owner remains alive" do
    assert BoundedTask.run(
             fn -> {:ok, :completed} end,
             1_000,
             Runtime.provider_timeout(),
             Runtime.provider_crashed()
           ) == {:ok, :completed}
  end

  test "excludes an explicitly suspended interval from the deadline" do
    test_process = self()

    task =
      Task.async(fn ->
        BoundedTask.run(
          fn -> suspended_effect(test_process) end,
          @execution_timeout,
          Runtime.provider_timeout(),
          Runtime.provider_crashed()
        )
      end)

    assert_receive {:approval_started, worker}, @receive_timeout
    task_reference = task.ref
    refute_receive {^task_reference, _result}, @execution_timeout + 100
    send(worker, :approved)

    assert Task.await(task, @receive_timeout) == {:ok, :completed}
  end

  test "resumes charging the remaining budget after suspension" do
    test_process = self()

    task =
      Task.async(fn ->
        BoundedTask.run(
          fn -> resumed_effect(test_process) end,
          @execution_timeout,
          Runtime.provider_timeout(),
          Runtime.provider_crashed()
        )
      end)

    assert_receive {:approval_started, worker}, @receive_timeout
    send(worker, :approved)
    assert_receive :active_work_started, @receive_timeout

    assert {:error, %{code: "provider_timeout"}} = Task.await(task, @receive_timeout)
  end

  test "terminates the effect task when its owner exits" do
    test_process = self()

    owner =
      spawn(fn ->
        BoundedTask.run(
          fn -> blocking_effect(test_process) end,
          30_000,
          Runtime.provider_timeout(),
          Runtime.provider_crashed()
        )
      end)

    owner_monitor = Process.monitor(owner)
    assert_receive {:effect_started, effect}, 5_000
    effect_monitor = Process.monitor(effect)

    # The acknowledgment orders monitor establishment before the guard's kill.
    send(effect, {:confirm_monitor, effect_monitor})
    assert_receive {:monitor_confirmed, ^effect_monitor}, 5_000

    Process.exit(owner, :kill)

    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}, 5_000
    assert_receive {:DOWN, ^effect_monitor, :process, ^effect, :killed}, 5_000
  end

  defp blocking_effect(test_process) do
    send(test_process, {:effect_started, self()})

    receive do
      {:confirm_monitor, reference} -> send(test_process, {:monitor_confirmed, reference})
    end

    receive do
      :finish -> {:ok, :completed}
    end
  end

  defp resumed_effect(test_process) do
    wait_for_approval(test_process)
    send(test_process, :active_work_started)
    Process.sleep(@execution_timeout + 100)
    {:ok, :completed}
  end

  defp suspended_effect(test_process) do
    wait_for_approval(test_process)
    {:ok, :completed}
  end

  defp wait_for_approval(test_process) do
    BoundedTask.without_timeout(fn ->
      send(test_process, {:approval_started, self()})

      receive do
        :approved -> :ok
      end
    end)
  end
end
