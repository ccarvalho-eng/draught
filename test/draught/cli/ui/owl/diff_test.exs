defmodule Draught.CLI.UI.Owl.DiffTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.UI.Owl.Diff

  test "renders an exact replacement as a safe bounded diff" do
    operation = %{
      "expected" => "one\ntwo\n",
      "path" => "lib/example.ex",
      "replacement" => "one\nthree\n"
    }

    assert {:ok, rendered} = Diff.replace_in_file(operation, false)

    expected =
      Enum.join(
        [
          "--- a/lib/example.ex",
          "+++ b/lib/example.ex",
          "@@ exact replacement @@",
          "- one",
          "- two",
          "- ",
          "+ one",
          "+ three",
          "+ "
        ],
        "\n"
      )

    assert IO.iodata_to_binary(rendered) == expected <> "\n"
  end

  test "escapes terminal controls and declines malformed replacement metadata" do
    operation = %{
      "expected" => "before\e[31m",
      "path" => "sample\nname.txt",
      "replacement" => "after\r"
    }

    assert {:ok, rendered} = Diff.replace_in_file(operation, true)
    output = IO.iodata_to_binary(rendered)
    plain = Regex.replace(~r/\e\[[0-9;]*m/, output, "")

    assert output =~ <<27>>
    assert plain =~ "a/sample\\nname.txt"
    assert plain =~ "- before\\u001B[31m"
    assert plain =~ "+ after\\r"

    for invalid <- [%{}, Map.delete(operation, "expected"), %{operation | "path" => 1}] do
      assert :unavailable = Diff.replace_in_file(invalid, false)
    end
  end
end
