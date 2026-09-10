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
  alias Draught.Tool.Execution.Failure
  alias Draught.Tool.Execution.Feedback
  alias Draught.Tool.Result

  @duplicate_feedback "This exact tool call was already attempted earlier in this turn. " <>
                        "Reuse its result or change the request."

  @doc "Converts an execution boundary result into a canonical result and message."
  @spec normalize(term(), Call.t()) ::
          {:ok, Result.t(), Draught.Conversation.Message.Tool.t()} | {:error, Normalized.t()}
  def normalize({:ok, %Result{} = result}, _call) do
    message(result)
  end

  def normalize({:error, %Normalized{} = error}, call) do
    failure(error, call, "")
  end

  def normalize(_result, _call) do
    {:error, Runtime.tool_crashed()}
  end

  @doc "Builds the recoverable result returned for one repeated tool call."
  @spec duplicate(Call.t()) ::
          {:ok, Result.t(), Draught.Conversation.Message.Tool.t()} | {:error, Normalized.t()}
  def duplicate(%Call{} = call) do
    failure(Failure.duplicate_tool_call(), call, @duplicate_feedback)
  end

  @doc "Builds one canonical error result with bounded model-facing feedback."
  @spec failure(Normalized.t(), Call.t(), String.t()) ::
          {:ok, Result.t(), Draught.Conversation.Message.Tool.t()} | {:error, Normalized.t()}
  def failure(%Normalized{} = error, %Call{} = call, content) when is_binary(content) do
    content = failure_content(content, error)

    result =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: content,
        status: :error,
        error: error
      )

    case result do
      {:ok, canonical} -> message(canonical)
      {:error, _error} -> {:error, Runtime.tool_crashed()}
    end
  end

  defp message(result) do
    case Conversation.tool(result) do
      {:ok, message} -> {:ok, result, message}
      {:error, _error} -> {:error, Runtime.tool_crashed()}
    end
  end

  defp failure_content("", error) do
    Feedback.content(error)
  end

  defp failure_content(content, _error) do
    content
  end
end
