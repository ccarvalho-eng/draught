defmodule Draught.Session.Runtime.Turn do
  @moduledoc false

  alias Draught.Execution.Runner
  alias Draught.Execution.Runner.BoundedTask.OwnerGuard
  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Settings
  alias Draught.Telemetry.SessionTurn

  @task_supervisor Draught.Execution.TaskSupervisor

  @doc "Starts one owner-guarded runner task and its whole-turn timer."
  @spec start(Settings.t(), pos_integer(), term(), pid(), pid()) :: ActiveTurn.t()
  def start(settings, turn_id, request, subscriber, session) do
    telemetry_span = SessionTurn.start()

    try do
      start_runtime(settings, turn_id, request, subscriber, session, telemetry_span)
    catch
      kind, reason ->
        :ok = SessionTurn.exception(telemetry_span, kind)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
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

  @doc "Completes the telemetry span owned by an active turn."
  @spec complete_span(ActiveTurn.t(), Draught.Execution.Runner.result()) :: :ok
  def complete_span(%ActiveTurn{} = active, outcome) do
    SessionTurn.stop(active.telemetry_span, outcome)
  end

  @doc "Marks the telemetry span owned by an active turn as exceptional."
  @spec exception_span(ActiveTurn.t(), :error | :exit | :throw) :: :ok
  def exception_span(%ActiveTurn{} = active, kind) do
    SessionTurn.exception(active.telemetry_span, kind)
  end

  defp start_runtime(settings, turn_id, request, subscriber, session, telemetry_span) do
    token = make_ref()
    sink = fn event -> emit(session, token, event) end
    run = fn -> execute(session, settings, request, sink) end
    task = Task.Supervisor.async_nolink(@task_supervisor, run)
    timer = Process.send_after(session, {:turn_timeout, token}, settings.turn_timeout_ms)
    ActiveTurn.new(turn_id, subscriber, task, telemetry_span, timer, token)
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
