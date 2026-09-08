defmodule Draught.CLI.Task.Stream.Indicator.State do
  @moduledoc """
  Holds the immutable lifecycle of one terminal activity indicator.

  Caption order is a complete permutation supplied by the presentation boundary.
  A deterministic catalog order is used for absent or malformed internal options.
  """

  alias Draught.CLI.Task.Stream.Indicator.Captions

  @default_delay_ms 120
  @default_interval_ms 80
  @default_maximum_bytes 16_384

  @enforce_keys [:delay_ms, :enabled, :interval_ms, :maximum_bytes]
  defstruct [
    :next_at,
    caption_order: Captions.order(),
    delay_ms: @default_delay_ms,
    emitted_bytes: 0,
    enabled: false,
    frame: 0,
    interval_ms: @default_interval_ms,
    maximum_bytes: @default_maximum_bytes,
    phase: :idle
  ]

  @type phase :: :idle | :waiting | :visible
  @type t :: %__MODULE__{
          caption_order: tuple(),
          delay_ms: non_neg_integer(),
          emitted_bytes: non_neg_integer(),
          enabled: boolean(),
          frame: non_neg_integer(),
          interval_ms: pos_integer(),
          maximum_bytes: pos_integer(),
          next_at: integer() | nil,
          phase: phase()
        }

  @doc "Builds a validated internal indicator state from trusted constants."
  @spec new(boolean(), keyword()) :: t()
  def new(enabled, options) when is_boolean(enabled) and is_list(options) do
    %__MODULE__{
      caption_order: caption_order(options),
      delay_ms: non_negative_option(options, :indicator_delay_ms, @default_delay_ms),
      enabled: enabled,
      interval_ms: positive_option(options, :indicator_interval_ms, @default_interval_ms),
      maximum_bytes: positive_option(options, :indicator_maximum_bytes, @default_maximum_bytes)
    }
  end

  defp caption_order(options) do
    default = Captions.order()
    candidate = Keyword.get(options, :indicator_caption_order, default)

    select_order(valid_order?(candidate, default), candidate, default)
  end

  defp select_order(true, candidate, _default) do
    candidate
  end

  defp select_order(false, _candidate, default) do
    default
  end

  defp valid_order?(candidate, default)
       when is_tuple(candidate) and tuple_size(candidate) == tuple_size(default) do
    sorted =
      candidate
      |> Tuple.to_list()
      |> Enum.sort()

    sorted === Tuple.to_list(default)
  end

  defp valid_order?(_candidate, _default) do
    false
  end

  defp non_negative_option(options, key, default) do
    case Keyword.get(options, key, default) do
      value when is_integer(value) and value >= 0 -> value
      _invalid -> default
    end
  end

  defp positive_option(options, key, default) do
    case Keyword.get(options, key, default) do
      value when is_integer(value) and value > 0 -> value
      _invalid -> default
    end
  end
end
