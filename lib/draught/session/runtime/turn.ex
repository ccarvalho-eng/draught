defmodule Draught.Session.Runtime.Turn do
  @moduledoc false

  alias Draught.Execution.Runner
  alias Draught.Execution.Runner.BoundedTask.OwnerGuard
  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Settings

  @task_supervisor Draught.Execution.TaskSupervisor

  @doc "Starts one owner-guarded runner task and its whole-turn timer."
  @spec start(Settings.t(), pos_integer(), term(), pid(), pid()) :: ActiveTurn.t()
  def start(settings, turn_id, request, subscriber, session) do
    token = make_ref()
    sink = fn event -> emit(session, token, event) end
    run = fn -> execute(session, settings, request, sink) end
    task = Task.Supervisor.async_nolink(@task_supervisor, run)
    timer = Process.send_after(session, {:turn_timeout, token}, settings.turn_timeout_ms)
    ActiveTurn.new(turn_id, subscriber, task, timer, token)
  end

  @doc "Stops a live turn task and cancels its timer."
  @spec stop(ActiveTurn.t()) :: :ok
  def stop(%ActiveTurn{} = active) do
    cancel_timer(active.timer)
    Task.shutdown(active.task, :brutal_kill)
    Process.demonitor(active.task.ref, [:flush])
    :ok
  end

  @doc "Releases monitoring and timer resources after a task result or exit."
  @spec finish(ActiveTurn.t()) :: :ok
  def finish(%ActiveTurn{} = active) do
    cancel_timer(active.timer)
    Process.demonitor(active.task.ref, [:flush])
    :ok
  end

  defp execute(session, settings, request, sink) do
    :ok = OwnerGuard.protect(session)

    settings.runner
    |> Map.from_struct()
    |> Map.put(:sink, sink)
    |> Runner.run(request)
  end

  defp emit(session, token, event) do
    send(session, {:runner_event, token, event})
    :ok
  end

  defp cancel_timer(timer) do
    Process.cancel_timer(timer, async: false, info: false)
    :ok
  end
end
