defmodule Draught.CLI.Release.ApplicationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.EntryPoint.Failure

  test "a runtime startup failure has sanitized output and a stable status" do
    assert Failure.startup() == {"Draught could not start.\n", 70}
  end
end
