defmodule Draught.Tool.Approval.Policy.Default do
  @moduledoc """
  Allows read risk and requests confirmation for effectful risks.
  """

  @behaviour Draught.Tool.Approval.Policy

  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request

  @impl Draught.Tool.Approval.Policy
  def decide(%Request{risk: :read}, _configuration) do
    Decision.new(outcome: :allow)
  end

  def decide(%Request{}, _configuration) do
    Decision.new(outcome: :ask)
  end
end
