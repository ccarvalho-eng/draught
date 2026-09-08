defmodule Draught.CLI.UI.Owl.JSONTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.UI.Owl.JSON

  test "renders stable indented JSON without changing its values" do
    preview = ~s({"workspace":"/tmp/project","arguments":["one",2,true,null]})

    assert {:ok, rendered} = JSON.render(preview, false)
    output = IO.iodata_to_binary(rendered)

    expected =
      Enum.join(
        [
          "{",
          ~s(  "arguments": [),
          ~s(    "one",),
          "    2,",
          "    true,",
          "    null",
          "  ],",
          ~s(  "workspace": "/tmp/project"),
          "}"
        ],
        "\n"
      )

    assert output == expected

    assert Jason.decode!(output) == Jason.decode!(preview)
    refute output =~ <<27>>
  end

  test "styles only JSON generated from parsed values" do
    preview = ~s({"path":"safe\\u001b[31mname","replacement":"after"})

    assert {:ok, rendered} = JSON.render(preview, true)
    output = IO.iodata_to_binary(rendered)
    plain = Regex.replace(~r/\e\[[0-9;]*m/, output, "")

    assert output =~ <<27>>
    assert plain =~ ~s("path": "safe\\u001B[31mname")
    assert Jason.decode!(plain) == Jason.decode!(preview)
  end

  test "rejects invalid, non-object, deeply nested, and oversized presentations" do
    nested = Enum.reduce(1..33, "null", fn _position, value -> "[#{value}]" end)
    oversized = Jason.encode!(%{"values" => Enum.to_list(1..16_384)})

    for preview <- ["invalid", "[]", ~s({"nested":#{nested}}), oversized] do
      assert {:error, :unavailable} = JSON.render(preview, false)
    end
  end
end
