defmodule Draught.Tool.Builtin.RunCommand.Failure do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Tool.Builtin.Failure
  alias Draught.Validation.Error

  @type reason :: :invalid_environment | :invalid_input | :not_found | Error.t() | Normalized.t()

  @doc "Normalizes a command preparation or execution failure."
  @spec normalize({:error, reason()}) :: {:error, Normalized.t()}
  def normalize({:error, :invalid_input}) do
    invalid_input()
  end

  def normalize({:error, :invalid_environment}) do
    invalid_environment()
  end

  def normalize({:error, :not_found}) do
    executable_not_found()
  end

  def normalize({:error, %Error{}}) do
    Failure.invalid_path()
  end

  def normalize({:error, %Normalized{}} = result) do
    result
  end

  @doc "Builds an error for invalid command input."
  @spec invalid_input() :: {:error, Normalized.t()}
  def invalid_input do
    error(:tool, "invalid_command", "Command input is invalid")
  end

  @doc "Builds an error for an unavailable executable."
  @spec executable_not_found() :: {:error, Normalized.t()}
  def executable_not_found do
    error(:tool, "executable_not_found", "Executable could not be found")
  end

  @doc "Builds an error for invalid internal environment configuration."
  @spec invalid_environment() :: {:error, Normalized.t()}
  def invalid_environment do
    error(:tool, "invalid_command_environment", "Command environment is invalid")
  end

  @doc "Builds an error for process startup or lifecycle failure."
  @spec execution_failed() :: {:error, Normalized.t()}
  def execution_failed do
    error(:tool, "command_execution_failed", "Command could not be executed")
  end

  @doc "Builds an error for invalid process output."
  @spec invalid_output() :: {:error, Normalized.t()}
  def invalid_output do
    error(:tool, "invalid_command_output", "Command returned invalid output")
  end

  @doc "Builds an error for output that exceeds the execution policy."
  @spec output_too_large() :: {:error, Normalized.t()}
  def output_too_large do
    error(:tool, "command_output_too_large", "Command output exceeded the configured limit")
  end

  @doc "Builds a command timeout error."
  @spec timeout() :: {:error, Normalized.t()}
  def timeout do
    error(:timeout, "command_timeout", "Command exceeded the configured timeout")
  end

  @doc "Builds a command cancellation error."
  @spec cancelled() :: {:error, Normalized.t()}
  def cancelled do
    error(:cancellation, "command_cancelled", "Command was cancelled")
  end

  defp error(kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)
    {:error, error}
  end
end
