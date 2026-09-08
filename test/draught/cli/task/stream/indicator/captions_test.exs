defmodule Draught.CLI.Task.Stream.Indicator.CaptionsTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream.Indicator.Captions

  test "opens with the initial fantasy captions" do
    assert Captions.at(0) == "Lollygagging…"
    assert Captions.at(1) == "Consulting the grimoire…"
    assert Captions.at(2) == "Rolling for insight…"
  end

  test "provides at least five hundred unique captions before repeating" do
    count = Captions.count()
    assert count >= 500
    captions = Enum.map(0..(count - 1), &Captions.at/1)
    assert length(Enum.uniq(captions)) == count
  end

  test "keeps every caption short and safe for terminal presentation" do
    for index <- 0..(Captions.count() - 1) do
      caption = Captions.at(index)
      assert String.valid?(caption)
      assert String.length(caption) in 1..32
      assert String.ends_with?(caption, "…")
      refute Regex.match?(~r/[\p{Cc}\p{Cf}]/u, caption)
    end
  end

  test "wraps deterministically for complete cycles and large offsets" do
    count = Captions.count()
    assert Captions.at(count) == Captions.at(0)

    for index <- 0..(count - 1) do
      assert Captions.at(count + index) == Captions.at(index)
      assert Captions.at(count * 1_000_000 + index) == Captions.at(index)
    end
  end
end
