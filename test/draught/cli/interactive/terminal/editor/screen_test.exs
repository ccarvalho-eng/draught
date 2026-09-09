defmodule Draught.CLI.Interactive.Terminal.Editor.ScreenTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Terminal.Editor.Buffer
  alias Draught.CLI.Interactive.Terminal.Editor.Screen

  test "lays out hard lines and wrapping from the prompt column" do
    initial = Buffer.new(64)
    assert {:ok, buffer} = Buffer.insert(initial, "abcd\nef")

    assert %{cursor: {2, 6}, end_position: {2, 6}} =
             Screen.layout(buffer, 8, 4)
  end

  test "redraws from the prior cursor and returns the next screen state" do
    initial = Buffer.new(64)
    assert {:ok, buffer} = Buffer.insert(initial, "one\ntwo")
    screen = Screen.new(20, 4, "│   ")
    {iodata, rendered} = Screen.redraw(screen, buffer)
    output = IO.iodata_to_binary(iodata)

    assert output =~ "one\r\n│   two"
    assert output =~ "\e[J"
    assert rendered.cursor_row == 1
  end

  test "projects a cursor positioned before the end of wrapped text" do
    initial = Buffer.new(64)
    assert {:ok, inserted} = Buffer.insert(initial, "abcdefgh")

    buffer =
      inserted
      |> Buffer.left()
      |> Buffer.left()
      |> Buffer.left()

    assert %{cursor: {1, 1}, end_position: {1, 4}} =
             Screen.layout(buffer, 8, 4)

    screen = Screen.new(8, 4, "│   ")
    {iodata, _screen} = Screen.redraw(screen, buffer)
    output = IO.iodata_to_binary(iodata)

    assert output =~ "abcdefgh"
    assert String.ends_with?(output, "\r\e[1C")
  end

  test "accounts for terminal tab stops in pasted content" do
    initial = Buffer.new(64)
    assert {:ok, buffer} = Buffer.insert(initial, "a\tb")

    assert %{cursor: {0, 9}, end_position: {0, 9}} =
             Screen.layout(buffer, 20, 4)
  end
end
