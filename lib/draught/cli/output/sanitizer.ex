defmodule Draught.CLI.Output.Sanitizer do
  @moduledoc """
  Removes terminal controls and hidden reasoning content from user-visible CLI output.
  """

  @ansi_sequence ~r/\x1B(?:\[[0-?]*[ -\/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))/u
  @unsafe_controls ~r/[\x00-\x08\x0B-\x1F\x7F\x{0080}-\x{009F}\x{061C}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/u

  @doc "Removes terminal command sequences and unsafe display controls from UTF-8 text."
  @spec text(String.t()) :: String.t()
  def text(value) when is_binary(value) do
    value
    |> String.replace(@ansi_sequence, "")
    |> String.replace(@unsafe_controls, "")
  end

  @doc "Removes unsafe controls and returns at most the requested UTF-8 byte prefix."
  @spec text(String.t(), pos_integer()) :: String.t()
  def text(value, maximum_bytes) when is_binary(value) and maximum_bytes > 0 do
    value
    |> text()
    |> bounded(maximum_bytes)
  end

  defp bounded(value, maximum_bytes) when byte_size(value) <= maximum_bytes do
    value
  end

  defp bounded(value, maximum_bytes) do
    value
    |> binary_part(0, maximum_bytes)
    |> valid_prefix()
  end

  defp valid_prefix(value) do
    valid_prefix(String.valid?(value), value)
  end

  defp valid_prefix(true, value) do
    value
  end

  defp valid_prefix(false, value) do
    shortened = binary_part(value, 0, byte_size(value) - 1)
    valid_prefix(shortened)
  end
end
