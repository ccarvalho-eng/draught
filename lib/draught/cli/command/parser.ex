defmodule Draught.CLI.Command.Parser do
  @moduledoc """
  Pure bounded parsing from operating-system arguments to canonical CLI intent.
  """

  alias Draught.CLI.Command.Arguments
  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.Intent
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Command.Options

  @doc "Parses bounded arguments without reading environment, files, or process state."
  @spec parse(term()) :: {:ok, Invocation.t()} | {:error, Error.t()}
  def parse(arguments) do
    with {:ok, parseable, literal} <- Arguments.prepare(arguments),
         {:ok, options, positionals} <- Options.parse(parseable) do
      Intent.resolve(positionals, literal, options)
    end
  end
end
