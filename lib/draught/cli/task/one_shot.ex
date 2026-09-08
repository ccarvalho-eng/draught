defmodule Draught.CLI.Task.OneShot do
  @moduledoc """
  Executes one prepared task through a temporary supervised session and returns its terminal result.
  """

  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot.Approval
  alias Draught.CLI.Task.OneShot.Lifecycle
  alias Draught.CLI.Task.OneShot.Mailbox
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Stream
  alias Draught.Session

  @doc "Executes one prepared turn through a temporary supervised session."
  @type result :: Draught.CLI.Task.result()

  @spec run(String.t(), Preparation.t()) :: result()
  def run(identifier, %Preparation{} = preparation) do
    {result, _stream} = run_observed(identifier, preparation, Stream.silent())
    result
  end

  @doc "Executes one prepared turn while threading an ordered CLI stream observer."
  @spec run_observed(String.t(), Preparation.t(), Stream.t()) :: {result(), Stream.t()}
  def run_observed(identifier, %Preparation{} = preparation, %Stream{} = stream) do
    options = Lifecycle.options(preparation.session_options, self())

    case Session.start(identifier, preparation.runner, options) do
      {:ok, session} ->
        run_session(identifier, session, preparation, stream, Lifecycle.wait_timeout(options))

      {:error, error} ->
        {{:error, :session, error}, stream}
    end
  end

  defp run_session(identifier, session, preparation, stream, wait_timeout_ms) do
    monitor = Lifecycle.monitor(session)
    deadline = System.monotonic_time(:millisecond) + wait_timeout_ms

    try do
      execute(identifier, session, preparation, stream, monitor, deadline)
    after
      Lifecycle.stop(session, monitor)
    end
  end

  defp execute(identifier, session, preparation, stream, monitor, deadline) do
    case Session.run_observed(identifier, preparation.request, self()) do
      {:ok, turn_id} -> await(identifier, session, turn_id, stream, monitor, deadline)
      {:error, error} -> {{:error, :session, error}, stream}
    end
  end

  defp await(identifier, session, turn_id, stream, monitor, deadline) do
    remaining_ms = remaining(deadline)
    indicator_wait = Stream.wait_timeout(stream, remaining_ms)

    identifier
    |> Mailbox.next(turn_id, stream, monitor, indicator_wait)
    |> handle_event(identifier, session, turn_id, stream, monitor, deadline)
  end

  defp handle_event(
         {:terminal, outcome},
         _identifier,
         _session,
         _turn,
         stream,
         _monitor,
         _deadline
       ) do
    {execution_result(outcome), Approval.close(stream)}
  end

  defp handle_event(:started, identifier, session, turn_id, stream, monitor, deadline) do
    started = Stream.start(stream)
    await(identifier, session, turn_id, started, monitor, deadline)
  end

  defp handle_event(
         {:runner, event, acknowledgement},
         identifier,
         session,
         turn_id,
         stream,
         monitor,
         deadline
       ) do
    observe(identifier, session, turn_id, stream, monitor, deadline, event, acknowledgement)
  end

  defp handle_event(:session_stopped, _identifier, _session, _turn, stream, _monitor, _deadline) do
    {{:error, :session, Failure.session_stopped()}, Approval.close(stream)}
  end

  defp handle_event(
         {:approval, operation},
         identifier,
         session,
         turn_id,
         stream,
         monitor,
         deadline
       ) do
    stream
    |> Approval.request(operation)
    |> approval_result(identifier, session, turn_id, monitor, deadline)
  end

  defp handle_event({:input, input}, identifier, session, turn_id, stream, monitor, deadline) do
    stream
    |> Approval.reply(input)
    |> approval_result(identifier, session, turn_id, monitor, deadline)
  end

  defp handle_event(:approval_stopped, identifier, _session, _turn, stream, _monitor, _deadline) do
    approval_error(identifier, stream)
  end

  defp handle_event(:elapsed, identifier, session, turn_id, stream, monitor, deadline) do
    wait_elapsed(identifier, session, turn_id, stream, monitor, deadline)
  end

  defp handle_event(:invalid_event, identifier, _session, _turn, stream, _monitor, _deadline) do
    stream_error(identifier, :invalid_event, stream)
  end

  defp wait_elapsed(identifier, session, turn_id, stream, monitor, deadline) do
    case {remaining(deadline), Approval.expired?(stream)} do
      {0, _approval_wait} ->
        cancel(identifier)
        {{:error, :session, Failure.wait_timeout()}, Approval.close(stream)}

      {_remaining, true} ->
        approval_error(identifier, stream)

      _remaining ->
        tick(identifier, session, turn_id, stream, monitor, deadline)
    end
  end

  defp approval_result({:ok, stream}, identifier, session, turn_id, monitor, deadline) do
    await(identifier, session, turn_id, stream, monitor, deadline)
  end

  defp approval_result({:error, stream}, identifier, _session, _turn_id, _monitor, _deadline) do
    approval_error(identifier, stream)
  end

  defp approval_error(identifier, stream) do
    closed = Approval.close(stream)
    cancel(identifier)
    {{:error, :execution, Failure.approval_unavailable()}, closed}
  end

  defp tick(identifier, session, turn_id, stream, monitor, deadline) do
    case Stream.tick(stream) do
      {:ok, updated} -> await(identifier, session, turn_id, updated, monitor, deadline)
      {:error, reason, failed} -> stream_error(identifier, reason, failed)
    end
  end

  defp observe(
         identifier,
         session,
         turn_id,
         stream,
         monitor,
         deadline,
         event,
         acknowledgement
       ) do
    case Stream.observe(stream, event) do
      {:ok, updated} ->
        Session.acknowledge(session, acknowledgement, :ok)
        await(identifier, session, turn_id, updated, monitor, deadline)

      {:error, reason, failed} ->
        Session.acknowledge(session, acknowledgement, :halt)
        stream_error(identifier, reason, failed)
    end
  end

  defp stream_error(identifier, reason, stream) do
    cancel(identifier)
    {{:error, :execution, stream_failure(reason)}, Approval.close(stream)}
  end

  defp remaining(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end

  defp cancel(identifier) do
    case Session.cancel(identifier) do
      :ok -> :ok
      {:error, _error} -> :ok
    end
  end

  defp execution_result({:ok, response}) do
    {:ok, response}
  end

  defp execution_result({:error, error}) do
    {:error, :execution, error}
  end

  defp stream_failure(:output_limit) do
    Failure.output_too_large()
  end

  defp stream_failure(:invalid_event) do
    Failure.invalid_stream_event()
  end

  defp stream_failure(_reason) do
    Failure.output_unavailable()
  end
end
