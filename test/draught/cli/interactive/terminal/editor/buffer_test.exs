defmodule Draught.CLI.Interactive.Terminal.Editor.BufferTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Terminal.Editor.Buffer

  test "edits Unicode text at the cursor" do
    initial = Buffer.new(32)
    assert {:ok, inserted} = Buffer.insert(initial, "hélo")
    moved = Buffer.left(inserted)
    assert {:ok, corrected} = Buffer.insert(moved, "l")
    assert Buffer.text(corrected) == "héllo"

    deleted =
      corrected
      |> Buffer.home()
      |> Buffer.right()
      |> Buffer.delete()

    assert Buffer.text(deleted) == "hllo"
    backspaced = Buffer.backspace(deleted)
    assert Buffer.text(backspaced) == "llo"
  end

  test "moves within logical lines and clamps to their lengths" do
    initial = Buffer.new(64)
    assert {:ok, inserted} = Buffer.insert(initial, "first\nx\nthird")

    middle = Buffer.up(inserted)
    assert Buffer.cursor(middle) == 7

    first = Buffer.up(middle)
    assert Buffer.cursor(first) == 1

    returned = Buffer.down(first)
    assert Buffer.cursor(returned) == 7

    home = Buffer.home(returned)
    end_of_line = Buffer.end_of_line(returned)
    assert Buffer.cursor(home) == 6
    assert Buffer.cursor(end_of_line) == 7
  end

  test "rejects an insertion atomically when it exceeds the byte limit" do
    initial = Buffer.new(5)
    assert {:ok, buffer} = Buffer.insert(initial, "four")
    assert {:error, :too_large} = Buffer.insert(buffer, "!!")
    assert Buffer.text(buffer) == "four"
  end
end
