defmodule Draught.Execution.BoundedTask.OwnerGuard do
  @moduledoc """
  Couples a bounded execution task to the lifetime of its owning process.

  A separate supervised guard monitors both processes and kills the child if
  the owner exits before the child completes.
  """

  @supervisor Draught.Execution.TaskSupervisor

  @doc "Installs owner-death cleanup before the calling task starts its effect."
  @spec protect(pid()) :: :ok
  def protect(owner) when is_pid(owner) do
    child = self()
    guard = fn -> guard(owner, child) end
    {:ok, guard_pid} = Task.Supervisor.start_child(@supervisor, guard)

    receive do
      {:owner_guard_ready, ^guard_pid} -> :ok
    end
  end

  defp guard(owner, child) do
    owner_monitor = Process.monitor(owner)
    child_monitor = Process.monitor(child)
    ready(owner, child, owner_monitor, child_monitor)
  end

  defp ready(owner, child, owner_monitor, child_monitor) do
    owner
    |> Process.alive?()
    |> ready_result(child, owner, owner_monitor, child_monitor)
  end

  defp ready_result(true, child, owner, owner_monitor, child_monitor) do
    send(child, {:owner_guard_ready, self()})
    await(owner, child, owner_monitor, child_monitor)
  end

  defp ready_result(false, child, _owner, _owner_monitor, child_monitor) do
    Process.exit(child, :kill)
    await_child(child, child_monitor)
  end

  defp await(owner, child, owner_monitor, child_monitor) do
    receive do
      {:DOWN, ^owner_monitor, :process, ^owner, _reason} ->
        Process.exit(child, :kill)
        await_child(child, child_monitor)

      {:DOWN, ^child_monitor, :process, ^child, _reason} ->
        Process.demonitor(owner_monitor, [:flush])
        :ok
    end
  end

  defp await_child(child, child_monitor) do
    receive do
      {:DOWN, ^child_monitor, :process, ^child, _reason} -> :ok
    end
  end
end
