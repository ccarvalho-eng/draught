defmodule Draught.CLI.Router do
  @moduledoc false

  alias Draught.CLI.Command
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Doctor
  alias Draught.CLI.Output
  alias Draught.CLI.Task
  alias Draught.CLI.Writer

  @doc "Routes one parsed command result without duplicating command or provider policy."
  @spec dispatch(
          {:ok, Command.Invocation.t()} | {:error, Command.Error.t()},
          Dependencies.t()
        ) :: non_neg_integer()
  def dispatch({:error, %Command.Error{} = error}, dependencies) do
    error
    |> Output.command_error()
    |> Writer.emit(:stderr, :usage, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{command: :help} = invocation}, dependencies) do
    invocation.output
    |> Output.help()
    |> Writer.emit(:stdout, :success, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{command: :version} = invocation}, dependencies) do
    invocation.output
    |> Output.version()
    |> Writer.emit(:stdout, :success, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{command: :doctor} = invocation}, dependencies) do
    Doctor.Command.run(invocation, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{command: :task} = invocation}, dependencies) do
    Task.Command.run(invocation, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{} = invocation}, dependencies) do
    invocation.output
    |> Output.unavailable()
    |> Writer.emit(:stderr, :execution, dependencies)
  end
end
