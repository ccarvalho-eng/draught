defmodule Draught.CLI.EntryPoint do
  @moduledoc """
  Starts the application and executes the operating-system CLI entry point.
  """

  alias Draught.CLI
  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Dependencies
  alias Draught.CLI.EntryPoint.Failure
  alias Draught.CLI.EntryPoint.Guard

  @doc "Starts the application, runs one escript invocation, and exits with its stable status."
  @spec main([String.t()]) :: no_return()
  def main(arguments) do
    execute(arguments, &start/1)
  end

  @doc "Runs the native release invocation after its application callback starts the runtime."
  @spec main_started([String.t()]) :: no_return()
  def main_started(arguments) do
    execute(arguments, &run/1)
  end

  @spec execute([String.t()], ([String.t()] -> non_neg_integer())) :: no_return()
  defp execute(arguments, operation) do
    status =
      arguments
      |> Guard.run(operation)
      |> guarded_status()

    System.halt(status)
  end

  defp start(arguments) do
    case Application.ensure_all_started(:draught) do
      {:ok, _applications} -> run(arguments)
      _error -> startup_failure()
    end
  end

  defp run(arguments) do
    case Dependencies.new() do
      {:ok, dependencies} -> CLI.run(arguments, dependencies)
      _error -> startup_failure()
    end
  end

  defp startup_failure do
    write_failure(Failure.startup())
  end

  defp guarded_status({:ok, status}) do
    status
  end

  defp guarded_status(:error) do
    IO.write(:stderr, "Draught stopped after an internal error.\n")
    ExitStatus.value(:internal)
  end

  defp write_failure({message, status}) do
    IO.write(:stderr, message)
    status
  end
end
