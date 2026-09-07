defmodule Draught.CLI.UI.SafeLine do
  @moduledoc """
  Projects untrusted display values onto one bounded terminal line.

  General task output may retain line breaks. Structural CLI fields may not,
  because a persisted path or record must not create additional terminal rows.
  """

  alias Draught.CLI.Output.Sanitizer

  @format_controls ~r/\p{Cf}/u
  @structural_whitespace ~r/[\t\r\n\p{Zl}\p{Zp}]/u

  @doc "Removes terminal controls and replaces line breaks within a byte bound."
  @spec text(String.t(), pos_integer()) :: String.t()
  def text(value, maximum_bytes) when is_binary(value) and maximum_bytes > 0 do
    value
    |> Sanitizer.text(maximum_bytes)
    |> String.replace(@format_controls, "")
    |> String.replace(@structural_whitespace, " ")
  end
end
