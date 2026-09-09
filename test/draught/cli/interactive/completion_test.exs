defmodule Draught.CLI.Interactive.CompletionTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Completion
  alias Draught.CLI.Interactive.Completion.Context
  alias Draught.CLI.Interactive.State

  test "completes a unique slash command from the reversed terminal line" do
    completion_context = context()

    assert expand("/he", completion_context) == {:yes, ~c"lp", []}
    assert expand("/do", completion_context) == {:yes, ~c"ctor", []}
    assert expand("/skills", completion_context) == {:yes, [], []}
  end

  test "returns bounded choices for ambiguous commands" do
    completion_context = context()

    assert {:yes, [], matches} = expand("/res", completion_context)
    assert matches == [~c"/resume", ~c"/restore"]
  end

  test "completes model references from the in-memory startup catalog" do
    completion_context = context()

    assert expand("/model qwe", completion_context) ==
             {:yes, ~c"n3-coder:30b", []}
  end

  test "completes skill names from metadata already listed by the shell" do
    {:ok, interactive_state} =
      State.display_skills(state(), ["review-changes", "review-tests", "testing"])

    completion_context = Context.from_state(interactive_state)

    assert expand("/skill test", completion_context) == {:yes, ~c"ing", []}

    assert expand("/skill review-", completion_context) ==
             {:yes, [], [~c"review-changes", ~c"review-tests"]}
  end

  test "does not complete prompts, unknown commands, or other arguments" do
    completion_context = context()

    assert expand("fix the tests", completion_context) == {:no, [], []}
    assert expand("/unknown", completion_context) == {:no, [], []}
    assert expand("/resume sess", completion_context) == {:no, [], []}
    assert Completion.expand(:invalid, completion_context) == {:no, [], []}
    assert Completion.expand([0xD800], completion_context) == {:no, [], []}
  end

  test "builds a data-only bounded context from interactive state" do
    interactive_state = state()
    completion = Context.from_state(interactive_state)

    assert completion.models == ["qwen3-coder:30b", "deepseek-r1:latest"]
    assert completion.skills == []
    assert "/help" in completion.commands
    assert "/provider" in completion.commands
  end

  defp context do
    interactive_state = state()
    Context.from_state(interactive_state)
  end

  defp expand(value, context) do
    value
    |> reverse()
    |> Completion.expand(context)
  end

  defp reverse(value) do
    value
    |> String.to_charlist()
    |> Enum.reverse()
  end

  defp state do
    {:ok, state} =
      State.new(
        session_id: "session-01",
        provider: "ollama",
        model: "qwen3-coder:30b",
        model_catalog: ["qwen3-coder:30b", "deepseek-r1:latest"],
        workspace: "/workspace",
        web: false
      )

    state
  end
end
