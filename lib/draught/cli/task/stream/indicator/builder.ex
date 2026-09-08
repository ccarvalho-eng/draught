defmodule Draught.CLI.Task.Stream.Indicator.Builder do
  @moduledoc """
  Chooses one shuffled caption deck at the invocation's presentation boundary.

  Randomness occurs once during construction, outside the pure indicator state
  transitions. Trusted callers may supply a complete order for deterministic tests.
  """

  alias Draught.CLI.Task.Stream.Indicator.Captions
  alias Draught.CLI.Task.Stream.Indicator.State

  @type state :: State.t()

  @doc "Builds the indicator with a fresh shuffled order unless one was supplied."
  @spec new(boolean(), keyword()) :: state()
  def new(enabled?, options) do
    options = Keyword.put_new_lazy(options, :indicator_caption_order, &shuffled_order/0)
    State.new(enabled?, options)
  end

  defp shuffled_order do
    Captions.order()
    |> Tuple.to_list()
    |> Enum.shuffle()
    |> List.to_tuple()
  end
end
