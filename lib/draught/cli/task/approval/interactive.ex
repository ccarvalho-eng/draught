defmodule Draught.CLI.Task.Approval.Interactive do
  @moduledoc """
  Requests one invocation-scoped terminal decision from the CLI owner.

  Reads retain their default permission. Effectful operations require a complete
  preview and a matching response. Approval remains pending until the owner
  answers or exits; no decision is retained for another call or persisted with
  a session.
  """

  @behaviour Draught.Tool.Approval.Policy

  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request

  @impl Draught.Tool.Approval.Policy
  def decide(%Request{risk: :read}, _configuration) do
    Decision.new(outcome: :allow)
  end

  def decide(%Request{preview: preview} = request, configuration) when is_binary(preview) do
    reference = make_ref()
    monitor = Process.monitor(configuration.owner)

    operation = {self(), reference, request}
    send(configuration.owner, {:draught_approval, configuration.scope, operation})

    await(configuration, reference, monitor)
  end

  def decide(%Request{}, _configuration) do
    Decision.new(outcome: :deny, reason: "A complete operation preview is required")
  end

  defp await(configuration, reference, monitor) do
    scope = configuration.scope

    receive do
      {:draught_approval_decision, ^scope, ^reference, outcome}
      when outcome in [:allow, :deny] ->
        Decision.new(outcome: outcome)

      {:DOWN, ^monitor, :process, _owner, _reason} ->
        Decision.new(outcome: :deny, reason: "The approval owner is unavailable")
    end
  after
    Process.demonitor(monitor, [:flush])
  end
end
