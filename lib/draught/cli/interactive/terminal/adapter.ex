defmodule Draught.CLI.Interactive.Terminal.Adapter do
  @moduledoc """
  Defines line input and restoration effects for an interactive terminal.

  Output remains on the existing CLI system boundary. Keeping input separate
  permits deterministic shell tests and prevents terminal libraries from
  entering the headless and JSON Lines paths.
  """

  alias Draught.CLI.Interactive.Completion.Context

  @type configuration :: term()
  @type input_result :: {:ok, String.t()} | :eof | :interrupted | {:error, :io}

  @doc "Returns whether standard input is attached to an interactive terminal."
  @callback interactive?(configuration()) :: boolean()

  @doc "Reads one terminal input record while preserving EOF and interruption."
  @callback read_line(configuration()) :: input_result()

  @doc "Reads one shell line with a bounded, effect-free completion snapshot."
  @callback read_line(Context.t(), configuration()) :: input_result()

  @doc "Starts a correlated read delivered as a draught_terminal_input message."
  @callback request_line(configuration()) :: {:ok, reference()} | {:error, :io}

  @doc "Revokes a pending input request without transferring its input to a successor."
  @callback cancel_read(reference(), configuration()) :: :ok

  @optional_callbacks read_line: 2, request_line: 1, cancel_read: 2

  @doc "Restores terminal state after normal, interrupted, or failed shell execution."
  @callback restore(configuration()) :: :ok
end
