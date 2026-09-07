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
end
