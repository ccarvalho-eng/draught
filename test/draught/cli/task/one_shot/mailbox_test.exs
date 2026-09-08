defmodule Draught.CLI.Task.OneShot.MailboxTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.OneShot.Mailbox
  alias Draught.CLI.Task.Stream

  test "ignores old scopes and turns while selecting the active event" do
    scope = make_ref()
    stream = %{Stream.silent() | approval: Prompt.new(scope, {String, nil})}
    stale_operation = {:draught_approval, make_ref(), :stale}
    stale_turn = {:draught_session, "session", {:turn_started, 1}}
    stale_input = {:draught_terminal_input, make_ref(), {:ok, "yes\n"}}
    send(self(), stale_operation)
    send(self(), stale_turn)
    send(self(), stale_input)
    send(self(), {:draught_session, "session", {:turn_started, 2}})

    assert Mailbox.next("session", 2, stream, make_ref(), 0) == :started
    assert_receive ^stale_operation
    assert_receive ^stale_turn
    assert_receive ^stale_input
  end

  test "unknown current-turn events fail closed without consuming unrelated messages" do
    stream = Stream.silent()
    unrelated = {:draught_session, "another", {:turn_started, 1}}
    send(self(), unrelated)
    send(self(), {:draught_session, "session", {:unexpected, 1}})

    assert Mailbox.next("session", 1, stream, make_ref(), 0) == :invalid_event
    assert_receive ^unrelated
  end
end
