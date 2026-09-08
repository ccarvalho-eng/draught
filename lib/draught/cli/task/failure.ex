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

  @doc "Builds the failure returned when incremental output exceeds its byte budget."
  @spec output_too_large() :: Normalized.t()
  def output_too_large do
    error(:policy, "cli_output_too_large", "CLI output exceeded the configured limit")
  end

  @doc "Builds the failure returned when the CLI output stream cannot accept more data."
  @spec output_unavailable() :: Normalized.t()
  def output_unavailable do
    error(:protocol, "cli_output_unavailable", "CLI output is unavailable")
  end

  @doc "Builds the failure returned for an invalid ordered runner event."
  @spec invalid_stream_event() :: Normalized.t()
  def invalid_stream_event do
    error(:protocol, "invalid_cli_stream_event", "CLI received an invalid stream event")
  end

  @doc "Builds the fail-closed result for interrupted or unavailable approval input."
  @spec approval_unavailable() :: Normalized.t()
  def approval_unavailable do
    error(
      :policy,
      "approval_input_unavailable",
      "Approval input became unavailable; the operation was not executed"
    )
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
