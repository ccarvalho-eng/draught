defmodule Draught.CLI.Output.Text do
  @moduledoc false

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Check
  alias Draught.CLI.Doctor.Report

  @doc "Renders structured help metadata for terminal output."
  @spec help(map()) :: iodata()
  def help(metadata) do
    [
      "Usage:\n",
      Enum.map(metadata.usage, &["  ", &1, "\n"]),
      "\nCommands:\n",
      Enum.map(metadata.commands, &command/1),
      "\nOptions:\n",
      Enum.map(metadata.options, &option/1),
      "\nExamples:\n",
      Enum.map(metadata.examples, &["  ", &1, "\n"])
    ]
  end

  @doc "Renders version metadata for terminal output."
  @spec version(map()) :: iodata()
  def version(metadata) do
    [metadata.name, " ", metadata.version, "\n"]
  end

  @doc "Renders a complete doctor report for terminal output."
  @spec doctor(Report.t()) :: iodata()
  def doctor(%Report{} = report) do
    [
      "Draught doctor\n",
      Enum.map(report.checks, &check/1),
      configuration(report.configuration)
    ]
  end

  @doc "Renders a bounded command parsing failure."
  @spec command_error(Command.Error.t()) :: iodata()
  def command_error(%Command.Error{} = error) do
    ["Error: ", error.message, "\nRun 'draught --help' for usage.\n"]
  end

  @doc "Renders a safe configuration failure."
  @spec configuration_error(Configuration.Error.t()) :: iodata()
  def configuration_error(%Configuration.Error{} = error) do
    [
      "Configuration error (",
      Atom.to_string(error.source),
      "/",
      Atom.to_string(error.code),
      "): ",
      error.message,
      "\n"
    ]
  end

  @doc "Renders the unavailable-execution result."
  @spec unavailable() :: iodata()
  def unavailable do
    "Agent execution is not available in this build. Run 'draught doctor' to check setup.\n"
  end

  @doc "Renders the named-task prompt requirement."
  @spec task_prompt_required() :: iodata()
  def task_prompt_required do
    "A task prompt is required. Pass it after --session ID or --resume ID.\n"
  end

  @doc "Renders a safe task setup failure."
  @spec task_setup_error(atom()) :: iodata()
  def task_setup_error(:provider) do
    "Task provider configuration is invalid. Run 'draught doctor' to inspect setup.\n"
  end

  def task_setup_error(_category) do
    "Task execution configuration is invalid.\n"
  end

  defp command(command) do
    ["  ", String.pad_trailing(command.name, 14), command.description, "\n"]
  end

  defp option(option) do
    label = option_label(option)
    ["  ", String.pad_trailing(label, 28), option.description, "\n"]
  end

  defp option_label(%{value: nil} = option) do
    option.switch
  end

  defp option_label(option) do
    option.switch <> " " <> option.value
  end

  defp check(%Check{} = check) do
    [
      check.name,
      ": ",
      Atom.to_string(check.status),
      " - ",
      check.message,
      "\n",
      hint(check.hint),
      details(check.details)
    ]
  end

  defp hint(nil) do
    []
  end

  defp hint(value) do
    ["  Hint: ", value, "\n"]
  end

  defp details(%{"compatible_models" => compatible, "incompatible_models" => incompatible}) do
    [
      model_line("Compatible models", compatible),
      model_line("Incompatible models", incompatible)
    ]
  end

  defp details(_details) do
    []
  end

  defp model_line(_label, []) do
    []
  end

  defp model_line(label, models) do
    ["  ", label, ": ", Enum.join(models, ", "), "\n"]
  end

  defp configuration(configuration) do
    [
      "Configuration:\n",
      "  Profile: ",
      configuration["profile"],
      "\n",
      "  Model: ",
      configuration["model"] || "automatic",
      "\n",
      "  Web: ",
      to_string(configuration["web"]),
      "\n"
    ]
  end
end
