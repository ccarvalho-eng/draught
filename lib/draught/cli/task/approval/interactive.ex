defmodule Draught.CLI.Task.Approval.Interactive do
  @moduledoc """
  Requests one invocation-scoped terminal decision from the CLI owner.

  Reads retain their default permission. Effectful operations require a complete
  preview and a matching, timely response. Owner death and expiry deny authority;
  no decision is retained for another call or persisted with a session.
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
    deadline = System.monotonic_time(:millisecond) + configuration.timeout_ms

    operation = {self(), reference, deadline, request}
    send(configuration.owner, {:draught_approval, configuration.scope, operation})

    await(configuration, reference, monitor, deadline)
  end

  def decide(%Request{}, _configuration) do
    Decision.new(outcome: :deny, reason: "A complete operation preview is required")
  end

  defp await(configuration, reference, monitor, deadline) do
    scope = configuration.scope
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:draught_approval_decision, ^scope, ^reference, outcome}
      when outcome in [:allow, :deny] ->
        timely_decision(outcome, deadline)

      {:DOWN, ^monitor, :process, _owner, _reason} ->
        Decision.new(outcome: :deny, reason: "The approval owner is unavailable")
    after
      remaining -> Decision.new(outcome: :deny, reason: "The approval deadline expired")
    end
  after
    Process.demonitor(monitor, [:flush])
  end

  defp timely_decision(outcome, deadline) do
    timely = System.monotonic_time(:millisecond) < deadline
    decision(timely, outcome)
  end

  defp decision(true, outcome) do
    Decision.new(outcome: outcome)
  end

  defp decision(false, _outcome) do
    Decision.new(outcome: :deny, reason: "The approval deadline expired")
  end
end
