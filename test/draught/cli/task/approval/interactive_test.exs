defmodule Draught.CLI.Task.Approval.InteractiveTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Interactive
  alias Draught.CLI.Task.Approval.Prompt
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
    configuration = %{owner: owner, scope: scope}

    task = start_policy(configuration)
    assert_receive {:draught_approval, ^scope, {requester, reference, _request}}
    send(requester, {:draught_approval_decision, make_ref(), reference, :allow})
    send(requester, {:draught_approval_decision, scope, make_ref(), :allow})
    send(requester, {:draught_approval_decision, scope, reference, :deny})
    assert {:ok, %Decision{outcome: :deny}} = Task.await(task)
  end

  test "allows one matching decision and denies when its owner is gone" do
    scope = make_ref()
    task = start_policy(%{owner: self(), scope: scope})
    assert_receive {:draught_approval, ^scope, {requester, reference, _request}}
    send(requester, {:draught_approval_decision, scope, reference, :allow})
    assert {:ok, %Decision{outcome: :allow}} = Task.await(task)

    owner = start_supervised!({Task, fn -> :ok end})
    monitor = Process.monitor(owner)
    assert_receive {:DOWN, ^monitor, :process, ^owner, _reason}
    orphan = start_policy(%{owner: owner, scope: make_ref()})
    assert {:ok, %Decision{outcome: :deny}} = Task.await(orphan)
  end

  test "waits for the user without an approval deadline" do
    scope = make_ref()
    task = start_policy(%{owner: self(), scope: scope})
    assert_receive {:draught_approval, ^scope, {requester, reference, _request}}
    task_reference = task.ref
    refute_receive {^task_reference, _result}, 25

    send(requester, {:draught_approval_decision, scope, reference, :allow})
    assert {:ok, %Decision{outcome: :allow}} = Task.await(task)
  end

  test "retains an explicit presentation style decision" do
    scope = make_ref()
    terminal = {Draught.CLI.Interactive.Terminal.Local, nil}

    assert Prompt.new(scope, terminal, true).styled?
    refute Prompt.new(scope, terminal, false).styled?
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
