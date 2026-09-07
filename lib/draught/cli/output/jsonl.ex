defmodule Draught.CLI.Output.JSONL do
  @moduledoc false

  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Check
  alias Draught.CLI.Doctor.Report

  @schema "draught.cli/v1"

  @doc "Encodes help metadata as one versioned JSONL record."
  @spec help(map()) :: {:ok, iodata()} | {:error, :encoding}
  def help(metadata) do
    encode(%{
      "schema" => @schema,
      "type" => "help",
      "usage" => metadata.usage,
      "commands" => Enum.map(metadata.commands, &command/1),
      "options" => Enum.map(metadata.options, &option/1),
      "examples" => metadata.examples
    })
  end

  @doc "Encodes version metadata as one versioned JSONL record."
  @spec version(map()) :: {:ok, iodata()} | {:error, :encoding}
  def version(metadata) do
    encode(%{
      "schema" => @schema,
      "type" => "version",
      "name" => metadata.name,
      "version" => metadata.version
    })
  end

  @doc "Encodes a complete doctor report as one versioned JSONL record."
  @spec doctor(Report.t()) :: {:ok, iodata()} | {:error, :encoding}
  def doctor(%Report{} = report) do
    encode(%{
      "schema" => @schema,
      "type" => "doctor",
      "status" => Atom.to_string(report.status),
      "checks" => Enum.map(report.checks, &check/1),
      "configuration" => report.configuration
    })
  end

  @doc "Encodes a safe configuration failure as one versioned JSONL record."
  @spec configuration_error(Configuration.Error.t()) :: {:ok, iodata()} | {:error, :encoding}
  def configuration_error(%Configuration.Error{} = error) do
    encode(%{
      "schema" => @schema,
      "type" => "error",
      "category" => "configuration",
      "source" => Atom.to_string(error.source),
      "code" => Atom.to_string(error.code),
      "message" => error.message
    })
  end

  @doc "Encodes the unavailable-execution result as one versioned JSONL record."
  @spec unavailable() :: {:ok, iodata()} | {:error, :encoding}
  def unavailable do
    encode(%{
      "schema" => @schema,
      "type" => "error",
      "category" => "execution",
      "code" => "not_available",
      "message" => "Agent execution is not available in this build"
    })
  end

  @doc "Encodes the named-task prompt requirement."
  @spec task_prompt_required() :: {:ok, iodata()} | {:error, :encoding}
  def task_prompt_required do
    encode(%{
      "schema" => @schema,
      "type" => "error",
      "category" => "session",
      "code" => "prompt_required",
      "message" => "A task prompt is required after the named session option"
    })
  end

  @doc "Encodes one safe task setup failure."
  @spec task_setup_error(atom()) :: {:ok, iodata()} | {:error, :encoding}
  def task_setup_error(category) do
    encode(%{
      "schema" => @schema,
      "type" => "error",
      "category" => Atom.to_string(category),
      "code" => "invalid_setup",
      "message" => setup_message(category)
    })
  end

  defp check(%Check{} = check) do
    %{
      "name" => check.name,
      "status" => Atom.to_string(check.status),
      "message" => check.message,
      "hint" => check.hint,
      "details" => check.details
    }
  end

  defp command(command) do
    %{"name" => command.name, "description" => command.description}
  end

  defp option(option) do
    %{
      "switch" => option.switch,
      "value" => option.value,
      "description" => option.description
    }
  end

  defp setup_message(:provider) do
    "Task provider configuration is invalid"
  end

  defp setup_message(_category) do
    "Task execution configuration is invalid"
  end

  defp encode(value) do
    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, [encoded, "\n"]}
      {:error, _error} -> {:error, :encoding}
    end
  end
end
