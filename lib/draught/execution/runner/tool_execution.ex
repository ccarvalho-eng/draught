defmodule Draught.Execution.Runner.ToolExecution do
  @moduledoc """
  Handles one ordered batch of tool calls for the runner.

  New calls run sequentially under the configured timeout. Repeated calls can
  be rejected without effects. Each canonical result is emitted before its
  corresponding conversation message is returned.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.BoundedTask
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Execution.Runner.Sink
  alias Draught.Execution.Runner.ToolExecution.Outcome
  alias Draught.Tool
  alias Draught.Tool.Call

  @doc "Executes calls sequentially and returns ordered tool-result messages."
  @spec run(Configuration.t(), pos_integer(), [Call.t()]) ::
          {:ok, [Draught.Conversation.Message.Tool.t()]} | {:error, Normalized.t()}
  def run(%Configuration{} = configuration, iteration, calls) do
    calls
    |> Enum.reduce_while({:ok, []}, fn call, {:ok, messages} ->
      execute_step(configuration, iteration, call, messages)
    end)
    |> reverse()
  end

  @doc "Rejects one repeated batch without executing effects and publishes matching results."
  @spec reject_duplicate(Configuration.t(), pos_integer(), [Call.t()]) ::
          {:ok, [Draught.Conversation.Message.Tool.t()]} | {:error, Normalized.t()}
  def reject_duplicate(%Configuration{} = configuration, iteration, calls) do
    calls
    |> Enum.reduce_while({:ok, []}, fn call, {:ok, messages} ->
      reject_step(configuration, iteration, call, messages)
    end)
    |> reverse()
  end

  defp execute_step(configuration, iteration, call, messages) do
    publish(execute(configuration, call), configuration, iteration, messages)
  end

  defp reject_step(configuration, iteration, call, messages) do
    publish(Outcome.duplicate(call), configuration, iteration, messages)
  end

  defp publish(outcome, configuration, iteration, messages) do
    with {:ok, result, message} <- outcome,
         :ok <- Sink.emit(configuration.sink, {:tool_result, iteration, result}) do
      {:cont, {:ok, [message | messages]}}
    else
      {:error, %Normalized{}} = result -> {:halt, result}
    end
  end

  defp execute(configuration, call) do
    effect = fn -> Tool.execute(configuration.registry, call, configuration.tool_context) end

    effect
    |> BoundedTask.run(
      configuration.limits.tool_timeout_ms,
      Runtime.tool_timeout(),
      Runtime.tool_crashed()
    )
    |> Outcome.normalize(call)
  end

  defp reverse({:ok, messages}) do
    {:ok, Enum.reverse(messages)}
  end

  defp reverse({:error, %Normalized{}} = result) do
    result
  end
end
