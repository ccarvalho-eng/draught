defmodule Draught.Execution.Runner.ToolExecution.Outcome do
  @moduledoc """
  Converts a bounded tool effect into runner-facing result values.

  Valid tool results become matching conversation messages. Malformed results
  and reconstruction failures collapse to the stable tool-task failure.
  """

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  @doc "Converts an execution boundary result into a canonical result and message."
  @spec normalize(term(), Call.t()) ::
          {:ok, Result.t(), Draught.Conversation.Message.Tool.t()} | {:error, Normalized.t()}
  def normalize({:ok, %Result{} = result}, _call) do
    message(result)
  end

  def normalize({:error, %Normalized{} = error}, call) do
    result =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: "",
        status: :error,
        error: error
      )

    case result do
      {:ok, canonical} -> message(canonical)
      {:error, _error} -> {:error, Runtime.tool_crashed()}
    end
  end

  def normalize(_result, _call) do
    {:error, Runtime.tool_crashed()}
  end

  defp message(result) do
    case Conversation.tool(result) do
      {:ok, message} -> {:ok, result, message}
      {:error, _error} -> {:error, Runtime.tool_crashed()}
    end
  end
end
