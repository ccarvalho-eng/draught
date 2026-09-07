defmodule Draught.Execution.Runner.BoundedTaskTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.Runner.BoundedTask
  alias Draught.Execution.Runner.Failure.Runtime

  test "returns the effect result while its owner remains alive" do
    assert BoundedTask.run(
             fn -> {:ok, :completed} end,
             1_000,
             Runtime.provider_timeout(),
             Runtime.provider_crashed()
           ) == {:ok, :completed}
  end

  test "terminates the effect task when its owner exits" do
    test_process = self()

    owner =
      spawn(fn ->
        BoundedTask.run(
          fn -> blocking_effect(test_process) end,
          5_000,
          Runtime.provider_timeout(),
          Runtime.provider_crashed()
        )
      end)

    owner_monitor = Process.monitor(owner)
    assert_receive {:effect_started, effect}
    effect_monitor = Process.monitor(effect)

    Process.exit(owner, :kill)

    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :killed}
    assert_receive {:DOWN, ^effect_monitor, :process, ^effect, :killed}
  end

  defp blocking_effect(test_process) do
    send(test_process, {:effect_started, self()})

    receive do
      :finish -> {:ok, :completed}
    end
  end
end
