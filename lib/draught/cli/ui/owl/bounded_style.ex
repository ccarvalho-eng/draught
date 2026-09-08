defmodule Draught.CLI.UI.Owl.BoundedStyle do
  @moduledoc """
  Chooses optional terminal styling without expanding a bounded view.

  When trusted ANSI decoration would exceed the caller's complete-output limit,
  the unchanged plain representation is retained instead.
  """

  @doc "Returns styled data when it fits, otherwise the complete plain data."
  @spec choose(iodata(), iodata(), pos_integer()) :: {:ok, iodata()}
  def choose(styled, plain, maximum) when is_integer(maximum) and maximum > 0 do
    styled
    |> IO.iodata_length()
    |> within_limit?(maximum)
    |> result(styled, plain)
  end

  defp within_limit?(length, maximum) do
    length <= maximum
  end

  defp result(true, styled, _plain) do
    {:ok, styled}
  end

  defp result(false, _styled, plain) do
    {:ok, plain}
  end
end
