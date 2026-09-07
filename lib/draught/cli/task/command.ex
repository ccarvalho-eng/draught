defmodule Draught.CLI.Task.Command do
  @moduledoc """
  Executes anonymous or named task invocations and emits their ordered CLI stream.
  """

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Output
  alias Draught.CLI.Task
  alias Draught.CLI.Task.Command.Result
  alias Draught.CLI.Task.Named
  alias Draught.CLI.Task.Stream
  alias Draught.CLI.Writer

  @doc "Runs one anonymous or named task command and emits its ordered result stream."
  @spec run(Command.Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(%Command.Invocation{prompt: prompt} = invocation, dependencies)
      when is_binary(prompt) do
    execute(invocation, dependencies)
  end

  def run(%Command.Invocation{} = invocation, dependencies) do
    invocation.output
    |> Output.task_prompt_required()
    |> Writer.emit(:stderr, :session, dependencies)
  end

  defp execute(invocation, %Dependencies{} = dependencies) do
    case Loader.load(invocation, dependencies.system) do
      {:ok, configuration, workspace} ->
        stream = Stream.new(invocation.output, dependencies.system, color: invocation.color)
        {result, observed} = task(invocation, configuration, workspace, dependencies, stream)
        Result.emit(result, observed)

      {:error, %Error{} = error} ->
        error
        |> Output.configuration_error(invocation.output)
        |> Writer.emit(:stderr, :usage, dependencies)
    end
  end

  defp task(
         %Command.Invocation{session: nil, resume: nil} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       ) do
    Task.run_observed(
      invocation.prompt,
      configuration,
      workspace,
      dependencies.task,
      stream
    )
  end

  defp task(
         %Command.Invocation{session: identifier} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       )
       when is_binary(identifier) do
    Named.run_observed(
      :create,
      identifier,
      invocation.prompt,
      configuration,
      workspace,
      environment(dependencies.system),
      dependencies.task,
      stream
    )
  end

  defp task(
         %Command.Invocation{resume: identifier} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       )
       when is_binary(identifier) do
    Named.run_observed(
      :resume,
      identifier,
      invocation.prompt,
      configuration,
      workspace,
      environment(dependencies.system),
      dependencies.task,
      stream
    )
  end

  defp environment({system, configuration}) do
    system.environment(configuration)
  end
end
