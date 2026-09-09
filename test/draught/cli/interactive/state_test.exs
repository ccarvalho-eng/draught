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

  test "renames and selects sessions only while idle" do
    current = state()
    selected = %{state() | session_id: "session-02", session_label: "Second"}

    assert {:ok, renamed} = State.rename(current, "Review session")
    assert renamed.session_label == "Review session"
    assert {:ok, ^selected} = State.select(current, selected)

    assert {:ok, running} = State.start_turn(current, "work")
    assert {:error, :busy} = State.rename(running, "Later")
    assert {:error, :busy} = State.select(running, selected)
  end

  test "selects a model only for an idle unpersisted session" do
    current = state()

    assert {:ok, selected} = State.select_model(current, "deepseek-r1")
    assert selected.model == "deepseek-r1"

    assert {:ok, running} = State.start_turn(current, "work")
    assert {:error, :busy} = State.select_model(running, "deepseek-r1")

    assert {:error, :persisted_model} =
             current
             |> State.persisted()
             |> State.select_model("deepseek-r1")

    assert {:error, :invalid_model} = State.select_model(current, "")
  end

  test "permits an unresolved model while interactive selection is required" do
    assert {:ok, state} =
             State.new(
               session_id: "session-01",
               provider: "ollama",
               model: nil,
               workspace: "/workspace",
               web: false
             )

    assert state.model == nil
    assert State.start_turn(state, "work") == {:error, :model_required}
    assert State.displayed_models(state) == {:error, :model_list_required}

    assert {:ok, displayed} = State.display_models(state, ["qwen3", "deepseek-r1"])
    assert State.displayed_models(displayed) == {:ok, ["qwen3", "deepseek-r1"]}
    assert State.display_models(state, [""]) == {:error, :invalid_model_catalog}
  end

  test "retains only a bounded canonical skill completion catalog" do
    assert {:ok, displayed} =
             State.display_skills(state(), ["review-changes", "testing"])

    assert displayed.skill_catalog == ["review-changes", "testing"]
    assert State.display_skills(state(), ["Review"]) == {:error, :invalid_skill_catalog}

    assert State.display_skills(state(), ["testing", "testing"]) ==
             {:error, :invalid_skill_catalog}

    oversized = Enum.map(1..257, &("skill-" <> Integer.to_string(&1)))
    assert State.display_skills(state(), oversized) == {:error, :invalid_skill_catalog}
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
