defmodule Draught.CLI.Task.Named.Resume.ValidationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Named.Resume.Validation
  alias Draught.Session.Journal.Replay

  test "rejects a session without a durably admitted first turn" do
    assert {:error, :session, error} =
             "empty-session"
             |> Replay.empty()
             |> Validation.resumable()

    assert error.code == "session_not_resumable"
  end
end
