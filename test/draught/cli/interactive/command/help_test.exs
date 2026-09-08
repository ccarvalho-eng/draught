defmodule Draught.CLI.Interactive.Command.HelpTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Command.Help

  test "renders active commands, reserved commands, and input forms" do
    rendered = Help.render()
    output = IO.iodata_to_binary(rendered)

    assert output =~ "Available commands"
    assert output =~ "/status"
    assert output =~ "/sessions"
    assert output =~ "Reserved for confined direct commands"
  end
end
