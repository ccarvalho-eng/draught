defmodule Draught.Execution.BoundedTask do
  @moduledoc """
  Runs one effect under the execution task supervisor with an execution-time budget.

  The boundary converts task exits and timeouts into caller-supplied normalized
  failures and ensures the task is terminated if its owner dies. Explicitly
  suspended intervals, such as waiting for human approval, do not consume the
  execution budget.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.BoundedTask.OwnerGuard

  @control_key {__MODULE__, :timeout_control}
  @message :draught_bounded_task

  @doc "Runs one supervised effect with a fixed execution budget and owner-death cleanup."
  @spec run((-> term()), pos_integer(), Normalized.t(), Normalized.t()) :: term()
  def run(effect, timeout_ms, timeout_error, crash_error) when is_function(effect, 0) do
    owner = self()
    token = make_ref()
    worker = start_worker(owner, token, effect)

    await_running(worker, token, timeout_ms, now(), timeout_error, crash_error)
  end

  @doc "Runs an effect without charging its duration to the nearest bounded task."
  @spec without_timeout((-> result)) :: result when result: term()
  def without_timeout(effect) when is_function(effect, 0) do
    case Process.get(@control_key) do
      nil -> effect.()
      control -> suspend(control, effect)
    end
  end

  defp timeout(worker, error) do
    stop(worker)
    {:error, error}
  end

  defp run_guarded(owner, token, effect) do
    :ok = OwnerGuard.protect(owner)
    previous = Process.put(@control_key, %{owner: owner, token: token, suspended?: false})

    try do
      result = effect.()
      send(owner, {@message, token, :result, self(), result})
    after
      restore_control(previous)
    end
  end

  defp await_running(
         {worker_pid, worker_monitor} = worker,
         token,
         remaining,
         started_at,
         timeout_error,
         crash_error
       ) do
    receive do
      {@message, ^token, :result, ^worker_pid, result} ->
        Process.demonitor(worker_monitor, [:flush])
        result

      {:DOWN, ^worker_monitor, :process, ^worker_pid, _reason} ->
        {:error, crash_error}

      {@message, ^token, :suspend, ^worker_pid, suspended_at} ->
        pause(worker, token, remaining, started_at, suspended_at, timeout_error, crash_error)
    after
      remaining -> timeout(worker, timeout_error)
    end
  end

  defp pause(worker, token, remaining, started_at, suspended_at, timeout_error, crash_error) do
    available = max(remaining - max(suspended_at - started_at, 0), 0)

    cond do
      available == 0 ->
        timeout(worker, timeout_error)

      available > 0 ->
        send(elem(worker, 0), {@message, token, :suspended})
        await_suspended(worker, token, available, timeout_error, crash_error)
    end
  end

  defp await_suspended(
         {worker_pid, worker_monitor} = worker,
         token,
         remaining,
         timeout_error,
         crash_error
       ) do
    receive do
      {@message, ^token, :result, ^worker_pid, result} ->
        Process.demonitor(worker_monitor, [:flush])
        result

      {:DOWN, ^worker_monitor, :process, ^worker_pid, _reason} ->
        {:error, crash_error}

      {@message, ^token, :resume, ^worker_pid} ->
        await_running(worker, token, remaining, now(), timeout_error, crash_error)
    end
  end

  defp suspend(%{suspended?: true}, effect) do
    effect.()
  end

  defp suspend(%{owner: owner, token: token} = control, effect) do
    send(owner, {@message, token, :suspend, self(), now()})

    receive do
      {@message, ^token, :suspended} -> run_suspended(control, effect)
    end
  end

  defp run_suspended(control, effect) do
    Process.put(@control_key, %{control | suspended?: true})

    try do
      effect.()
    after
      Process.put(@control_key, control)
      send(control.owner, {@message, control.token, :resume, self()})
    end
  end

  defp restore_control(nil) do
    Process.delete(@control_key)
    :ok
  end

  defp restore_control(previous) do
    Process.put(@control_key, previous)
    :ok
  end

  defp start_worker(owner, token, effect) do
    guarded_effect = fn -> run_guarded(owner, token, effect) end
    {:ok, worker} = Task.Supervisor.start_child(Draught.Execution.TaskSupervisor, guarded_effect)
    {worker, Process.monitor(worker)}
  end

  defp stop({worker, monitor}) do
    Process.exit(worker, :kill)

    receive do
      {:DOWN, ^monitor, :process, ^worker, _reason} -> :ok
    end
  end

  defp now do
    System.monotonic_time(:millisecond)
  end
end
