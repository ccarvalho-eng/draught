defmodule Draught.Execution.Runner.ToolResults do
  @moduledoc false

  alias Draught.Conversation.Message
  alias Draught.Conversation.Message.Tool
  alias Draught.Tool.Call
  alias Draught.Validation.Error

  @doc "Reconstructs and matches one ordered result message for each pending call."
  @spec reconcile([Call.t()], [Tool.t()]) :: Error.result([Tool.t()])
  def reconcile(calls, messages) when is_list(messages) do
    with {:ok, canonical} <- canonical_messages(messages),
         :ok <- matching_results(calls, canonical) do
      {:ok, canonical}
    end
  end

  def reconcile(_calls, _messages) do
    invalid_messages()
  end

  defp canonical_messages(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &canonical_message/2)
    |> reverse_messages()
  end

  defp canonical_message({message, index}, {:ok, canonical}) do
    case Message.validate(message) do
      {:ok, %Tool{} = tool} -> {:cont, {:ok, [tool | canonical]}}
      _result -> {:halt, invalid_message(index)}
    end
  end

  defp reverse_messages({:ok, messages}) do
    {:ok, Enum.reverse(messages)}
  end

  defp reverse_messages({:error, %Error{}} = result) do
    result
  end

  defp matching_results(calls, messages) do
    expected = Enum.map(calls, &{&1.id, &1.name})
    actual = Enum.map(messages, &{&1.result.call_id, &1.result.name})
    matching_results_result(expected == actual)
  end

  defp matching_results_result(true) do
    :ok
  end

  defp matching_results_result(false) do
    Error.single(
      [:messages],
      :invalid_relationship,
      "must contain one ordered result for every pending tool call"
    )
  end

  defp invalid_message(index) do
    Error.single([:messages, index], :invalid_type, "must be a tool message")
  end

  defp invalid_messages do
    Error.single([:messages], :invalid_type, "must be a list of tool messages")
  end
end
