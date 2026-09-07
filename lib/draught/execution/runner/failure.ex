defmodule Draught.Execution.Runner.Failure do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Builds the terminal error for iteration exhaustion."
  @spec iteration_limit() :: Normalized.t()
  def iteration_limit do
    error("iteration_limit", "Agent run reached the configured iteration limit")
  end

  @doc "Builds the terminal error for a repeated semantic tool-call batch."
  @spec duplicate_tool_batch() :: Normalized.t()
  def duplicate_tool_batch do
    error("duplicate_tool_batch", "Provider repeated an identical tool-call batch")
  end

  defp error(code, message) do
    {:ok, error} = Normalized.new(:policy, code, message, retryable: false)
    error
  end
end
