defmodule Draught.CLI.Task.OneShot do
  @moduledoc """
  Executes one prepared task through a temporary supervised session and returns its terminal result.
  """

  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot.Lifecycle
  alias Draught.CLI.Task.Preparation
  alias Draught.Session

  @doc "Executes one prepared turn through a temporary supervised session."
  @type result ::
          {:ok, Draught.Provider.Response.t()}
          | {:error, :execution | :session,
             Draught.Error.Normalized.t() | Draught.Validation.Error.t()}

  @spec run(String.t(), Preparation.t()) :: result()
  def run(identifier, %Preparation{} = preparation) do
    options = Lifecycle.options(preparation.session_options, self())

    case Session.start(identifier, preparation.runner, options) do
      {:ok, session} ->
        run_session(identifier, session, preparation, Lifecycle.wait_timeout(options))

      {:error, error} ->
        {:error, :session, error}
    end
  end

  defp run_session(identifier, session, preparation, wait_timeout_ms) do
    monitor = Lifecycle.monitor(session)

    try do
      execute(identifier, preparation, monitor, wait_timeout_ms)
    after
      Lifecycle.stop(session, monitor)
    end
  end

  defp execute(identifier, preparation, monitor, wait_timeout_ms) do
    case Session.run(identifier, preparation.request, self()) do
      {:ok, turn_id} -> await(identifier, turn_id, monitor, wait_timeout_ms)
      {:error, error} -> {:error, :session, error}
    end
  end

  defp await(identifier, turn_id, monitor, wait_timeout_ms) do
    receive do
      {:draught_session, ^identifier, {:turn_terminal, ^turn_id, outcome}} ->
        execution_result(outcome)

      {:draught_session, ^identifier, {:turn_started, ^turn_id}} ->
        await(identifier, turn_id, monitor, wait_timeout_ms)

      {:draught_session, ^identifier, {:runner, ^turn_id, _event}} ->
        await(identifier, turn_id, monitor, wait_timeout_ms)

      {:DOWN, ^monitor, :process, _session, _reason} ->
        {:error, :session, Failure.session_stopped()}
    after
      wait_timeout_ms ->
        cancel(identifier)
        {:error, :session, Failure.wait_timeout()}
    end
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
end
