defmodule Draught.CLI.Task.Approval.Fixed do
  @moduledoc false

  @behaviour Draught.Tool.Approval.Policy

  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request

  @impl Draught.Tool.Approval.Policy
  def decide(%Request{}, outcome) when outcome in [:allow, :deny] do
    Decision.new(outcome: outcome)
  end
end
