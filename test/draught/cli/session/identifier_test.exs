defmodule Draught.CLI.Session.IdentifierTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Identifier

  test "generates portable random UUID identifiers" do
    assert {:ok, first} = Identifier.generate()
    assert {:ok, second} = Identifier.generate()

    assert first != second
    assert first =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    assert {:ok, ^first} = Draught.Session.Identifier.new(first)
  end
end
