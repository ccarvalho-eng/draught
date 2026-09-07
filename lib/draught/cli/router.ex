defmodule Draught.CLI.Router do
  @moduledoc """
  Routes parsed CLI invocations to help, diagnostics, task execution, or unavailable interactive paths.
  """

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

  def dispatch(
        {:ok, %Command.Invocation{resume: resume, session: session} = invocation},
        dependencies
      )
      when is_binary(resume) or is_binary(session) do
    invocation.output
    |> Output.task_prompt_required()
    |> Writer.emit(:stderr, :session, dependencies)
  end

  def dispatch({:ok, %Command.Invocation{} = invocation}, dependencies) do
    invocation.output
    |> Output.unavailable()
    |> Writer.emit(:stderr, :execution, dependencies)
  end
end
