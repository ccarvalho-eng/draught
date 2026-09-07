defmodule Draught.Execution.Runner.Failure.Runtime do
  @moduledoc """
  Constructs normalized failures for bounded runner effects.

  It centralizes stable error kinds and codes for provider, tool, output, and
  event-sink failures without retaining process exit reasons.
  """

  alias Draught.Error.Normalized

  @doc "Builds a provider timeout failure."
  @spec provider_timeout() :: Normalized.t()
  def provider_timeout do
    error(:timeout, "provider_timeout", "Provider exceeded the configured timeout")
  end

  @doc "Builds a provider task failure."
  @spec provider_crashed() :: Normalized.t()
  def provider_crashed do
    error(:protocol, "provider_task_failed", "Provider task terminated unexpectedly")
  end

  @doc "Builds a tool timeout failure."
  @spec tool_timeout() :: Normalized.t()
  def tool_timeout do
    error(:timeout, "tool_timeout", "Tool exceeded the configured timeout")
  end

  @doc "Builds a tool task failure."
  @spec tool_crashed() :: Normalized.t()
  def tool_crashed do
    error(:tool, "tool_task_failed", "Tool task terminated unexpectedly")
  end

  @doc "Builds a provider output-limit failure."
  @spec provider_output_too_large() :: Normalized.t()
  def provider_output_too_large do
    error(:policy, "provider_output_too_large", "Provider output exceeded the configured limit")
  end

  @doc "Builds an event-sink contract failure."
  @spec invalid_sink_result() :: Normalized.t()
  def invalid_sink_result do
    error(:configuration, "invalid_event_sink_result", "Event sink must return ok")
  end

  defp error(kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)
    error
  end
end
