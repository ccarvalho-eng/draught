defmodule Draught.CLI.Task.Failure do
  @moduledoc """
  Constructs normalized failures for invalid task preparation and execution state.
  """

  alias Draught.Error.Normalized

  @doc "Builds the bounded wait failure for a one-shot session."
  @spec wait_timeout() :: Normalized.t()
  def wait_timeout do
    error(:timeout, "task_wait_timeout", "Task did not reach a terminal state in time")
  end

  @doc "Builds the bounded failure for a session that exits before its result."
  @spec session_stopped() :: Normalized.t()
  def session_stopped do
    error(:protocol, "task_session_stopped", "Task session stopped before completion")
  end

  @doc "Builds the failure returned when a task identifier cannot be generated."
  @spec invalid_identifier() :: Normalized.t()
  def invalid_identifier do
    error(:configuration, "invalid_task_identifier", "Task session identifier is unavailable")
  end

  @doc "Builds the explicit result for web execution without an injected search capability."
  @spec web_unavailable() :: Normalized.t()
  def web_unavailable do
    error(
      :capability,
      "web_execution_unavailable",
      "Web execution is not available until a search adapter is configured"
    )
  end

  defp error(kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)
    error
  end
end
