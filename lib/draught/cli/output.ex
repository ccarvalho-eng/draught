defmodule Draught.CLI.Output do
  @moduledoc """
  Renders complete terminal or JSONL records without performing I/O.
  """

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Report
  alias Draught.CLI.Output.JSONL
  alias Draught.CLI.Output.Text

  @type result :: {:ok, iodata()} | {:error, :encoding}

  @doc "Renders command help as one complete record."
  @spec help(:text | :jsonl) :: result()
  def help(:text) do
    {:ok, Text.help(Command.help())}
  end

  def help(:jsonl) do
    JSONL.help(Command.help())
  end

  @doc "Renders application version as one complete record."
  @spec version(:text | :jsonl) :: result()
  def version(:text) do
    {:ok, Text.version(Command.version())}
  end

  def version(:jsonl) do
    JSONL.version(Command.version())
  end

  @doc "Renders one doctor report in the requested format."
  @spec doctor(Report.t(), :text | :jsonl) :: result()
  def doctor(%Report{} = report, :text) do
    {:ok, Text.doctor(report)}
  end

  def doctor(%Report{} = report, :jsonl) do
    JSONL.doctor(report)
  end

  @doc "Renders a bounded command parsing failure."
  @spec command_error(Command.Error.t()) :: result()
  def command_error(%Command.Error{} = error) do
    {:ok, Text.command_error(error)}
  end

  @doc "Renders a safe configuration failure in the requested format."
  @spec configuration_error(Configuration.Error.t(), :text | :jsonl) :: result()
  def configuration_error(%Configuration.Error{} = error, :text) do
    {:ok, Text.configuration_error(error)}
  end

  def configuration_error(%Configuration.Error{} = error, :jsonl) do
    JSONL.configuration_error(error)
  end

  @doc "Renders the temporary explicit execution boundary."
  @spec unavailable(:text | :jsonl) :: result()
  def unavailable(:text) do
    {:ok, Text.unavailable()}
  end

  def unavailable(:jsonl) do
    JSONL.unavailable()
  end
end
