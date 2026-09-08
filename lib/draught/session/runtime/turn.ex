defmodule Draught.Session.Runtime.Turn do
  @moduledoc """
  Runs one bounded agent turn and forwards its terminal outcome to the session server.
  """

  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Runtime.Turn.Execution
  alias Draught.Session.Runtime.Turn.Sink
  alias Draught.Session.Settings
  alias Draught.Telemetry.SessionTurn

  @task_supervisor Draught.Execution.TaskSupervisor

  @doc "Starts one owner-guarded runner task and its whole-turn timer."
  @spec start(Settings.t(), pos_integer(), term(), pid(), pid(), ActiveTurn.delivery()) ::
          ActiveTurn.t()
  def start(settings, turn_id, request, subscriber, session, delivery) do
    telemetry_span = SessionTurn.start()

    try do
      start_runtime(settings, turn_id, request, subscriber, session, telemetry_span, delivery)
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

  defp start_runtime(
         settings,
         turn_id,
         request,
         subscriber,
         session,
         telemetry_span,
         delivery
       ) do
    token = make_ref()
    sink = fn event -> Sink.emit(session, token, event) end
    run = fn -> Execution.run(session, settings, request, sink) end
    task = Task.Supervisor.async_nolink(@task_supervisor, run)
    timer = start_timer(session, token, settings.turn_timeout_ms)
    ActiveTurn.new(turn_id, subscriber, task, telemetry_span, timer, token, delivery)
  end

  defp start_timer(_session, _token, :infinity) do
    nil
  end

  defp start_timer(session, token, timeout_ms) do
    Process.send_after(session, {:turn_timeout, token}, timeout_ms)
  end

  defp cancel_timer(nil) do
    :ok
  end

  defp cancel_timer(timer) do
    Process.cancel_timer(timer, async: false, info: false)
    :ok
  end
end
