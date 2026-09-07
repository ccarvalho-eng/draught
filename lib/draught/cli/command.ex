defmodule Draught.CLI.Command do
  @moduledoc """
  Parses command-line arguments and exposes terminal-independent command metadata.
  """

  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Command.Metadata
  alias Draught.CLI.Command.Parser

  @doc "Parses bounded command-line arguments into a canonical invocation."
  @spec parse(term()) :: {:ok, Invocation.t()} | {:error, Error.t()}
  def parse(arguments) do
    Parser.parse(arguments)
  end

  @doc "Returns structured help data for a renderer."
  @spec help() :: Metadata.help_metadata()
  def help do
    Metadata.help()
  end

  @doc "Returns structured application version data for a renderer."
  @spec version() :: Metadata.version_metadata()
  def version do
    Metadata.version()
  end
end
