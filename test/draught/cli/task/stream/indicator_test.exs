defmodule Draught.CLI.Task.Stream.IndicatorTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream.Indicator
  alias Draught.CLI.Task.Stream.Indicator.Captions
  alias Draught.CLI.Task.Stream.Indicator.State

  test "animates the spinner while retaining a caption for fifty frames" do
    state = State.new(true, indicator_delay_ms: 0)
    started = Indicator.start(state, 0)
    assert {:emit, first, first_output} = Indicator.tick(started, 0)
    assert IO.iodata_to_binary(first_output) == "\r\e[2K⠋ Lollygagging…"
    assert {:emit, _second, second_output} = Indicator.tick(first, first.next_at)
    assert IO.iodata_to_binary(second_output) == "\r\e[2K⠙ Lollygagging…"
  end

  test "rotates restrained captions and wraps without changing execution state" do
    state = State.new(true, indicator_delay_ms: 0)
    started = Indicator.start(state, 0)

    cycle = Captions.count() * 50

    for {frame, caption} <- [
          {50, "Consulting the grimoire…"},
          {100, "Rolling for insight…"},
          {cycle, "Lollygagging…"}
        ] do
      assert {:emit, next, output} = Indicator.tick(%{started | frame: frame}, 0)
      assert IO.iodata_to_binary(output) == "\r\e[2K⠋ #{caption}"
      assert next.frame == frame + 1
      assert next.phase == :visible
    end
  end

  test "uses every caption in the supplied order before repeating" do
    order =
      Captions.order()
      |> Tuple.to_list()
      |> Enum.reverse()
      |> List.to_tuple()

    state = State.new(true, indicator_delay_ms: 0, indicator_caption_order: order)
    started = Indicator.start(state, 0)

    for position <- 0..(Captions.count() - 1) do
      caption =
        order
        |> elem(position)
        |> Captions.at()

      assert {:emit, next, output} = Indicator.tick(%{started | frame: position * 50}, 0)
      assert IO.iodata_to_binary(output) == "\r\e[2K⠋ #{caption}"
      assert next.next_at == state.interval_ms
    end

    assert {:emit, _next, output} = Indicator.tick(%{started | frame: Captions.count() * 50}, 0)

    first_caption =
      order
      |> elem(0)
      |> Captions.at()

    assert IO.iodata_to_binary(output) =~ first_caption
  end

  test "rejects incomplete, duplicate, or untrusted caption orders" do
    floats =
      Captions.order()
      |> Tuple.to_list()
      |> Enum.map(&(&1 * 1.0))
      |> List.to_tuple()

    for order <- [nil, {}, {0}, floats, Tuple.duplicate(0, Captions.count()), {"\e[31m"}] do
      state = State.new(true, indicator_caption_order: order)
      assert state.caption_order == Captions.order()
    end
  end
end
