defmodule Draught.CLI.Interactive.Terminal.Adapter do
  @moduledoc """
  Defines line input and restoration effects for an interactive terminal.

  Output remains on the existing CLI system boundary. Keeping input separate
  permits deterministic shell tests and prevents terminal libraries from
  entering the headless and JSON Lines paths.
  """

  @type configuration :: term()
  @type input_result :: {:ok, String.t()} | :eof | :interrupted | {:error, :io}

  @doc "Returns whether standard input is attached to an interactive terminal."
  @callback interactive?(configuration()) :: boolean()

  @doc "Reads one terminal input record while preserving EOF and interruption."
  @callback read_line(configuration()) :: input_result()

  @doc "Restores terminal state after normal, interrupted, or failed shell execution."
  @callback restore(configuration()) :: :ok
end
