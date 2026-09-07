defmodule Draught.CLI.Interactive.StateTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.State

  test "starts idle with trusted session display data" do
    assert {:ok, state} =
             State.new(
               session_id: "session-01",
               provider: "ollama",
               model: "qwen3",
               workspace: "/workspace",
               web: false
             )

    assert state.phase == :idle
    assert state.session_id == "session-01"
    assert state.queued_prompt == nil
    refute state.persisted?
  end

  test "moves through a turn and exposes one queued next turn" do
    state = state()

    assert {:ok, running} = State.start_turn(state, "first")
    assert running.phase == :running
    assert running.active_prompt == "first"

    assert {:ok, queued} = State.queue_prompt(running, "second")
    assert queued.queued_prompt == "second"
    assert {:error, :queue_full} = State.queue_prompt(queued, "third")

    assert {:next, next, "second"} = State.finish_turn(queued, true)
    assert next.phase == :running
    assert next.active_prompt == "second"
    assert next.queued_prompt == nil
    assert next.persisted?

    assert {:idle, idle} = State.finish_turn(next, true)
    assert idle.phase == :idle
    assert idle.active_prompt == nil
  end

  test "requires an explicit approval outcome" do
    assert {:ok, running} = State.start_turn(state(), "change a file")
    assert {:ok, awaiting} = State.request_approval(running, "approval-01")
    assert awaiting.phase == :awaiting_approval

    assert {:ok, resumed} = State.resolve_approval(awaiting, "approval-01")
    assert resumed.phase == :running
    assert resumed.approval_id == nil

    assert {:error, :stale_approval} =
             State.resolve_approval(awaiting, "approval-02")
  end

  test "cancels active work on the first interrupt and exits on the second" do
    assert {:ok, running} = State.start_turn(state(), "work")
    assert {:cancel, stopping} = State.interrupt(running)
    assert stopping.phase == :stopping
    assert {:exit, 130, stopped} = State.interrupt(stopping)
    assert stopped.phase == :stopped
  end

  test "exits immediately when idle" do
    assert {:exit, 130, stopped} = State.interrupt(state())
    assert stopped.phase == :stopped
  end

  defp state do
    {:ok, state} =
      State.new(
        session_id: "session-01",
        provider: "ollama",
        model: "qwen3",
        workspace: "/workspace",
        web: false
      )

    state
  end
end
