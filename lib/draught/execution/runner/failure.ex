defmodule Draught.Execution.Runner.Failure do
  @moduledoc """
  Constructs terminal policy failures produced by runner state transitions.

  These failures are non-retryable and expose stable codes for bounded-loop
  termination and repeated batches that continue after recoverable feedback.
  """

  alias Draught.Error.Normalized

  @doc "Builds the terminal error for iteration exhaustion."
  @spec iteration_limit() :: Normalized.t()
  def iteration_limit do
    error("iteration_limit", "Agent run reached the configured iteration limit")
  end

  @doc "Builds the terminal error when duplicate feedback does not stop a repeated batch."
  @spec duplicate_tool_batch() :: Normalized.t()
  def duplicate_tool_batch do
    error("duplicate_tool_batch", "Provider repeated an identical tool-call batch")
  end

  defp error(code, message) do
    {:ok, error} = Normalized.new(:policy, code, message, retryable: false)
    error
  end
end
