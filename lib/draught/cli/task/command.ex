defmodule Draught.CLI.Task.Command do
  @moduledoc false

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Output
  alias Draught.CLI.Task
  alias Draught.CLI.Task.Command.Result
  alias Draught.CLI.Task.Named
  alias Draught.CLI.Writer

  @doc "Runs one anonymous or named task command and emits its terminal result."
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
        result = task(invocation, configuration, workspace, dependencies)
        Result.emit(result, invocation, dependencies)

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
         dependencies
       ) do
    Task.run(invocation.prompt, configuration, workspace, dependencies.task)
  end

  defp task(
         %Command.Invocation{session: identifier} = invocation,
         configuration,
         workspace,
         dependencies
       )
       when is_binary(identifier) do
    Named.run(
      :create,
      identifier,
      invocation.prompt,
      configuration,
      workspace,
      environment(dependencies.system),
      dependencies.task
    )
  end

  defp task(
         %Command.Invocation{resume: identifier} = invocation,
         configuration,
         workspace,
         dependencies
       )
       when is_binary(identifier) do
    Named.run(
      :resume,
      identifier,
      invocation.prompt,
      configuration,
      workspace,
      environment(dependencies.system),
      dependencies.task
    )
  end

  defp environment({system, configuration}) do
    system.environment(configuration)
  end
end
