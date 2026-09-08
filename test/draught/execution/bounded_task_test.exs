defmodule Draught.Execution.BoundedTaskTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.BoundedTask
  alias Draught.Execution.Runner.Failure.Runtime

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

    result =
      BoundedTask.run(
        fn ->
          BoundedTask.without_timeout(fn ->
            send(test_process, :approval_started)
            Process.sleep(25)
          end)

          {:ok, :completed}
        end,
        10,
        Runtime.provider_timeout(),
        Runtime.provider_crashed()
      )

    assert_receive :approval_started
    assert result == {:ok, :completed}
  end

  test "resumes charging the remaining budget after suspension" do
    result =
      BoundedTask.run(
        fn ->
          Process.send_after(self(), :decision, 25)

          BoundedTask.without_timeout(fn ->
            receive do
              :decision -> :ok
            end
          end)

          Process.sleep(25)
          {:ok, :completed}
        end,
        10,
        Runtime.provider_timeout(),
        Runtime.provider_crashed()
      )

    assert {:error, %{code: "provider_timeout"}} = result
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
end
