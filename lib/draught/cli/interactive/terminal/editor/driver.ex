defmodule Draught.CLI.Interactive.Terminal.Editor.Driver do
  @moduledoc """
  Defines raw terminal effects used by the interactive prompt editor.

  The editor owns no operating-system or OTP terminal calls directly, keeping
  byte decoding and state transitions deterministic under tests.
  """

  @callback enter_raw(configuration :: term()) :: :ok | {:error, :unsupported}
  @callback restore(configuration :: term()) :: :ok
  @callback read(configuration :: term()) ::
              {:ok, String.t()} | :eof | {:error, :io}
  @callback write(iodata(), configuration :: term()) :: :ok | {:error, :io}
  @callback columns(configuration :: term()) :: pos_integer()
end
