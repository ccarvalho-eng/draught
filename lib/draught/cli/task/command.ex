defmodule Draught.CLI.Task.Command do
  @moduledoc """
  Executes anonymous or named task invocations and emits their ordered CLI stream.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Output
  alias Draught.CLI.Task.Command.Execution
  alias Draught.CLI.Writer

  @doc "Runs one anonymous or named task command and emits its ordered result stream."
  @spec run(Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(%Invocation{prompt: prompt} = invocation, dependencies)
      when is_binary(prompt) do
    execute(invocation, dependencies)
  end

  def run(%Invocation{} = invocation, dependencies) do
    invocation.output
    |> Output.task_prompt_required()
    |> Writer.emit(:stderr, :session, dependencies)
  end

  @doc "Runs a task from an already resolved configuration and workspace snapshot."
  @spec run_resolved(
          Invocation.t(),
          Configuration.t(),
          String.t(),
          Dependencies.t()
        ) :: non_neg_integer()
  def run_resolved(
        %Invocation{prompt: prompt} = invocation,
        %Configuration{} = configuration,
        workspace,
        %Dependencies{} = dependencies
      )
      when is_binary(prompt) and is_binary(workspace) do
    Execution.run(invocation, configuration, workspace, dependencies)
  end

  def run_resolved(
        %Invocation{} = invocation,
        %Configuration{},
        _workspace,
        %Dependencies{} = dependencies
      ) do
    invocation.output
    |> Output.task_prompt_required()
    |> Writer.emit(:stderr, :session, dependencies)
  end

  defp execute(invocation, %Dependencies{} = dependencies) do
    case Loader.load(invocation, dependencies.system) do
      {:ok, configuration, workspace} ->
        Execution.run(invocation, configuration, workspace, dependencies)

      {:error, error} ->
        error
        |> Output.configuration_error(invocation.output)
        |> Writer.emit(:stderr, :usage, dependencies)
    end
  end
end
