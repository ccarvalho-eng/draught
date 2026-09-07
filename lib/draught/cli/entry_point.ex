defmodule Draught.CLI.EntryPoint do
  @moduledoc false

  alias Draught.CLI
  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Dependencies
  alias Draught.CLI.EntryPoint.Guard

  @doc "Starts the application, runs one escript invocation, and exits with its stable status."
  @spec main([String.t()]) :: no_return()
  def main(arguments) do
    status =
      arguments
      |> Guard.run(&start/1)
      |> guarded_status()

    System.halt(status)
  end

  defp start(arguments) do
    with {:ok, _applications} <- Application.ensure_all_started(:draught),
         {:ok, dependencies} <- Dependencies.new() do
      CLI.run(arguments, dependencies)
    else
      _error ->
        IO.write(:stderr, "Draught could not start.\n")
        ExitStatus.value(:internal)
    end
  end

  defp guarded_status({:ok, status}) do
    status
  end

  defp guarded_status(:error) do
    IO.write(:stderr, "Draught stopped after an internal error.\n")
    ExitStatus.value(:internal)
  end
end
