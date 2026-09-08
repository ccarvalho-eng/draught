defmodule Draught.CLI.Task.Approval.InteractiveTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Interactive
  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Approval.Prompt.Pending
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request

  test "read operations do not request terminal input" do
    read = request(:read)
    assert {:ok, %Decision{outcome: :allow}} = Interactive.decide(read, nil)
    refute_receive {:draught_approval, _, _}
  end

  test "requires a complete preview for an effectful operation" do
    write = request(:write)
    assert {:ok, %Decision{outcome: :deny}} = Interactive.decide(write, nil)
    refute_receive {:draught_approval, _, _}
  end

  test "accepts only a reply for the current invocation and operation" do
    owner = self()
    scope = make_ref()
    configuration = %{owner: owner, scope: scope, timeout_ms: 1_000}

    task = start_policy(configuration)
    assert_receive {:draught_approval, ^scope, {requester, reference, _deadline, _request}}
    send(requester, {:draught_approval_decision, make_ref(), reference, :allow})
    send(requester, {:draught_approval_decision, scope, make_ref(), :allow})
    send(requester, {:draught_approval_decision, scope, reference, :deny})
    assert {:ok, %Decision{outcome: :deny}} = Task.await(task)
  end

  test "allows one matching decision and denies when its owner is gone" do
    scope = make_ref()
    task = start_policy(%{owner: self(), scope: scope, timeout_ms: 1_000})
    assert_receive {:draught_approval, ^scope, {requester, reference, _deadline, _request}}
    send(requester, {:draught_approval_decision, scope, reference, :allow})
    assert {:ok, %Decision{outcome: :allow}} = Task.await(task)

    owner = start_supervised!({Task, fn -> :ok end})
    monitor = Process.monitor(owner)
    assert_receive {:DOWN, ^monitor, :process, ^owner, _reason}
    orphan = start_policy(%{owner: owner, scope: make_ref(), timeout_ms: 1_000})
    assert {:ok, %Decision{outcome: :deny}} = Task.await(orphan)
  end

  test "zero remaining approval time cannot grant authority" do
    scope = make_ref()
    task = start_policy(%{owner: self(), scope: scope, timeout_ms: 0})
    assert {:ok, %Decision{outcome: :deny}} = Task.await(task)
  end

  test "an expired displayed prompt denies even a matching affirmative reply" do
    scope = make_ref()
    reference = make_ref()
    deadline = System.monotonic_time(:millisecond) - 1
    pending = Pending.new(self(), reference, deadline, make_ref())

    prompt = %{
      Prompt.new(scope, {Draught.CLI.Interactive.Terminal.Local, nil})
      | pending: pending
    }

    assert {:error, %{pending: nil}} = Prompt.reply(prompt, {:ok, "y\n"})
    assert_receive {:draught_approval_decision, ^scope, ^reference, :deny}
    refute_receive {:draught_approval_decision, ^scope, ^reference, :allow}
  end

  defp start_policy(configuration) do
    Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, fn ->
      Interactive.decide(%{request(:write) | preview: ~s({"path":"sample.txt"})}, configuration)
    end)
  end

  defp request(risk) do
    {:ok, request} =
      Request.new(
        call_id: "call",
        tool: "replace_in_file",
        target: "sample.txt",
        arguments_summary: "replace one match",
        risk: risk
      )

    request
  end
end
