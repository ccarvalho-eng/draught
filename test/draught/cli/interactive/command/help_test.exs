defmodule Draught.CLI.Interactive.Command.HelpTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Command.Help

  test "distinguishes available commands from unavailable planned commands" do
    rendered = Help.render()
    output = IO.iodata_to_binary(rendered)

    assert output =~ "Available commands:"
    assert output =~ "/status"
    assert output =~ "/permissions"
    assert output =~ "/clear"
    assert output =~ "/sessions"
    assert output =~ "/skills"
    assert output =~ "/skill REF"
    assert output =~ "/tools"
    assert output =~ "Unavailable commands:"
    assert output =~ "/provider"
    assert output =~ "Unavailable input forms:"
    assert output =~ "Reserved for confined direct commands"
  end
end
