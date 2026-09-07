defmodule Draught.CLI.System.Adapter do
  @moduledoc """
  Defines the operating-system boundary used by the CLI.
  """

  @type configuration :: term()
  @type stream :: :stdout | :stderr
  @type file_result :: {:ok, binary()} | :missing | {:error, :io | :too_large | :unsafe_file}

  @doc "Returns the current workspace candidate."
  @callback cwd(configuration()) :: {:ok, String.t()} | {:error, :io}

  @doc "Returns an immutable environment snapshot."
  @callback environment(configuration()) :: %{optional(String.t()) => String.t()}

  @doc "Reads at most the requested number of bytes from a regular non-symlink file."
  @callback read_file(String.t(), pos_integer(), configuration()) :: file_result()

  @doc "Checks whether a workspace is an accessible directory without mutating it."
  @callback workspace(String.t(), configuration()) ::
              :ok | {:error, :inaccessible | :not_directory}

  @doc "Writes one complete CLI record to a standard stream."
  @callback write(stream(), iodata(), configuration()) :: :ok | {:error, :closed | :io}

  @doc "Returns whether a standard stream is attached to a terminal."
  @callback tty?(stream(), configuration()) :: boolean()

  @doc "Returns the current terminal width when available."
  @callback columns(configuration()) :: {:ok, pos_integer()} | {:error, :unavailable}
end
