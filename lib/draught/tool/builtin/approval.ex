defmodule Draught.Tool.Builtin.Approval do
  @moduledoc """
  Applies the configured approval policy to built-in tool operations.

  Summaries remain bounded and sanitized. Optional operation previews contain
  escaped sensitive details for the trusted display boundary. Decisions are
  normalized to permission or stable policy failures before execution.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Approval
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Failure
  alias Draught.Tool.Risk
  alias Draught.Validation.Error

  @doc "Requests approval from sanitized built-in tool metadata."
  @spec authorize(Call.t(), Context.t(), Risk.t(), String.t(), String.t(), Request.preview()) ::
          :ok | {:error, Normalized.t()}
  def authorize(%Call{} = call, %Context{} = context, risk, target, summary, preview \\ nil) do
    with {:ok, request} <- request(call, risk, target, summary, preview),
         {:ok, decision} <- Approval.decide(context.approval, request) do
      decision(decision)
    else
      {:error, %Error{}} -> {:error, Failure.invalid_tool_result()}
      {:error, %Normalized{}} = result -> result
    end
  end

  defp request(call, risk, target, summary, preview) do
    Request.new(
      call_id: call.id,
      tool: call.name,
      target: target,
      arguments_summary: summary,
      risk: risk,
      preview: preview
    )
  end

  defp decision(%Decision{outcome: :allow}) do
    :ok
  end

  defp decision(%Decision{outcome: :ask}) do
    {:error, Failure.approval_required()}
  end

  defp decision(%Decision{outcome: :deny, reason: reason}) do
    {:error, Failure.approval_denied(reason)}
  end
end
