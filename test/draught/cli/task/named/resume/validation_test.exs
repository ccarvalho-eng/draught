defmodule Draught.CLI.Task.Named.Resume.ValidationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Named.Resume.Validation
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Session.Journal.Replay

  test "rejects a session without a durably admitted first turn" do
    assert {:error, :session, error} =
             "empty-session"
             |> Replay.empty()
             |> Validation.resumable()

    assert error.code == "session_not_resumable"
  end

  test "accepts a failed turn after its partial messages are discarded" do
    {:ok, error} =
      Normalized.new(
        :policy,
        "iteration_limit",
        "Agent run reached the configured iteration limit",
        retryable: false
      )

    replay = %{Replay.empty("failed-session") | terminal: {:completed, 1, {:error, error}}}

    assert :ok = Validation.resumable(replay)
  end

  test "accepts an interrupted turn from its last complete assistant boundary" do
    {:ok, user} = Conversation.user("completed prompt")
    {:ok, assistant} = Conversation.assistant(content: "completed response")

    replay = %{
      Replay.empty("interrupted-session")
      | messages: [user, assistant],
        terminal: {:interrupted, 2}
    }

    assert :ok = Validation.resumable(replay)
  end
end
