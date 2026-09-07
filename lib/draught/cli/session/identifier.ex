defmodule Draught.CLI.Session.Identifier do
  @moduledoc """
  Generates portable opaque identifiers for CLI-created sessions.

  UUID version and variant bits are fixed after drawing cryptographically
  strong random bytes. Callers can inject a deterministic generator through
  the existing task dependency boundary in tests and embedded use.
  """

  @doc "Generates one lower-case UUID version 4 session identifier."
  @spec generate() :: {:ok, String.t()}
  def generate do
    <<prefix::48, _version::4, middle::12, _variant::2, suffix::62>> =
      :crypto.strong_rand_bytes(16)

    <<prefix::48, 4::4, middle::12, 2::2, suffix::62>>
    |> Base.encode16(case: :lower)
    |> format()
    |> then(&{:ok, &1})
  end

  defp format(hexadecimal) do
    IO.iodata_to_binary([
      String.slice(hexadecimal, 0, 8),
      "-",
      String.slice(hexadecimal, 8, 4),
      "-",
      String.slice(hexadecimal, 12, 4),
      "-",
      String.slice(hexadecimal, 16, 4),
      "-",
      String.slice(hexadecimal, 20, 12)
    ])
  end
end
