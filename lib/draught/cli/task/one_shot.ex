defmodule Draught.CLI.Task.OneShot do
  @moduledoc """
  Executes one prepared task through a temporary supervised session and returns its terminal result.
  """

  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot.Lifecycle
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Stream
  alias Draught.Session

  @doc "Executes one prepared turn through a temporary supervised session."
  @type result ::
          {:ok, Draught.Provider.Response.t()}
          | {:error, :execution | :session,
             Draught.Error.Normalized.t() | Draught.Validation.Error.t()}

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
    wait_timeout_ms = Stream.wait_timeout(stream, remaining_ms)

    receive do
      {:draught_session, ^identifier, {:turn_terminal, ^turn_id, outcome}} ->
        {execution_result(outcome), stream}

      {:draught_session, ^identifier, {:turn_started, ^turn_id}} ->
        stream
        |> Stream.start()
        |> then(&await(identifier, session, turn_id, &1, monitor, deadline))

      {:draught_session, ^identifier, {:runner, ^turn_id, event, acknowledgement}} ->
        observe(
          identifier,
          session,
          turn_id,
          stream,
          monitor,
          deadline,
          event,
          acknowledgement
        )

      {:DOWN, ^monitor, :process, _session, _reason} ->
        {{:error, :session, Failure.session_stopped()}, stream}
    after
      wait_timeout_ms ->
        wait_elapsed(identifier, session, turn_id, stream, monitor, deadline)
    end
  end

  defp wait_elapsed(identifier, session, turn_id, stream, monitor, deadline) do
    case remaining(deadline) do
      0 ->
        cancel(identifier)
        {{:error, :session, Failure.wait_timeout()}, stream}

      _remaining ->
        tick(identifier, session, turn_id, stream, monitor, deadline)
    end
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
    {{:error, :execution, stream_failure(reason)}, stream}
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
