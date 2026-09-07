defmodule Draught.CLI.Session.Catalog.NameTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Catalog.Name

  test "accepts normalized printable Unicode names" do
    assert {:ok, "Revisão"} = Name.validate("Revisão")
  end

  test "rejects display controls and non-normalized names" do
    unsafe = [
      "review\u202Etxt",
      "zero\u200Bwidth",
      "soft\u00ADhyphen",
      "line\u2028separator",
      "Revisa\u0303o"
    ]

    Enum.each(unsafe, fn name ->
      assert {:error, error} = Name.validate(name)
      assert [%{path: [:session_name]}] = error.violations
    end)
  end
end
