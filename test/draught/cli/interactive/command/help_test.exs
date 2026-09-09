defmodule Draught.CLI.Interactive.Command.HelpTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Command.Help

  test "distinguishes available commands from unavailable planned commands" do
    rendered = Help.render()
    output = IO.iodata_to_binary(rendered)

    assert output =~ "Available now:"
    assert output =~ "/status"
    assert output =~ "/sessions"
    assert output =~ "Planned commands (not available yet):"
    assert output =~ "/provider"
    assert output =~ "Planned input forms (not available yet):"
    assert output =~ "Reserved for confined direct commands"
  end
end
