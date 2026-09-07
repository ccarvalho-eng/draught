defmodule Draught.Execution.BoundedTask.Stream do
  @moduledoc """
  Runs one streaming effect through an ordered, synchronous, bounded relay.

  The provider task cannot advance past an event until the owner has processed
  it. This preserves event/result ordering while retaining timeout, crash, owner
  death, and cumulative transient-output limits at one boundary.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.BoundedTask
  alias Draught.Execution.BoundedTask.OwnerGuard
  alias Draught.Execution.BoundedTask.Stream.State

  @message :draught_bounded_stream

  @doc "Runs one supervised streaming effect with ordered event acknowledgement."
  @spec run(
          ((term() -> term()) -> term()),
          (term() -> term()),
          pos_integer(),
          pos_integer(),
          Normalized.t(),
          Normalized.t(),
          Normalized.t()
        ) :: term()
  def run(
        effect,
        sink,
        timeout_ms,
        maximum_bytes,
        timeout_error,
        crash_error,
        output_error
      )
      when is_function(effect, 1) and is_function(sink, 1) do
    owner = self()
    relay = make_ref()
    guarded_effect = fn -> run_guarded(owner, relay, effect) end
    task = Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, guarded_effect)
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    errors = [timeout: timeout_error, crash: crash_error, output: output_error]

    task
    |> State.new(relay, sink, maximum_bytes, deadline, errors)
    |> await()
  end

  defp await(%State{} = state) do
    timeout_ms = max(state.deadline - System.monotonic_time(:millisecond), 0)

    state
    |> receive_message(timeout_ms)
    |> handle_message(state)
  end

  defp receive_message(
         %State{relay: relay, task: %Task{pid: task_pid, ref: task_ref}},
         timeout_ms
       ) do
    receive do
      {^task_ref, result} -> {:result, result}
      {:DOWN, ^task_ref, :process, _pid, _reason} -> :task_down
      {@message, ^relay, ^task_pid, event} -> {:event, event}
    after
      timeout_ms -> :timeout
    end
  end

  defp handle_message({:result, result}, state) do
    Process.demonitor(state.task.ref, [:flush])
    result
  end

  defp handle_message(:task_down, state) do
    {:error, state.crash_error}
  end

  defp handle_message({:event, event}, state) do
    relay_event(state, event)
  end

  defp handle_message(:timeout, state) do
    stop(state.task)
    {:error, state.timeout_error}
  end

  defp relay_event(state, event) do
    next_bytes = state.consumed_bytes + :erlang.external_size(event)
    continue_event(next_bytes <= state.maximum_bytes, state, event, next_bytes)
  end

  defp continue_event(true, state, event, next_bytes) do
    case run_sink(state, event) do
      {:ok, result} -> acknowledge(state, result, next_bytes)
      {:error, error} -> stop_with_error(state, error)
    end
  end

  defp continue_event(false, state, _event, _next_bytes) do
    stop_with_error(state, state.output_error)
  end

  defp acknowledge(state, result, next_bytes) do
    send(state.task.pid, {@message, state.relay, result})

    state
    |> State.consume(next_bytes)
    |> await()
  end

  defp run_sink(state, event) do
    remaining_ms = max(state.deadline - System.monotonic_time(:millisecond), 0)
    run_sink(remaining_ms, state, event)
  end

  defp run_sink(0, state, _event) do
    {:error, state.timeout_error}
  end

  defp run_sink(remaining_ms, state, event) do
    result =
      BoundedTask.run(
        fn -> state.sink.(event) end,
        remaining_ms,
        state.timeout_error,
        state.crash_error
      )

    sink_result(result)
  end

  defp sink_result({:error, %Normalized{} = error}) do
    {:error, error}
  end

  defp sink_result(result) do
    {:ok, result}
  end

  defp stop_with_error(state, error) do
    stop(state.task)
    {:error, error}
  end

  defp run_guarded(owner, relay, effect) do
    :ok = OwnerGuard.protect(owner)
    effect.(fn event -> deliver(owner, relay, event) end)
  end

  defp deliver(owner, relay, event) do
    send(owner, {@message, relay, self(), event})

    receive do
      {@message, ^relay, result} -> result
    end
  end

  defp stop(task) do
    Task.shutdown(task, :brutal_kill)
    :ok
  end
end
