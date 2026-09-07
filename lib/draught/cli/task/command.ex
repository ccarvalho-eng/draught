defmodule Draught.CLI.Task.Command do
  @moduledoc false

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Output
  alias Draught.CLI.Task
  alias Draught.CLI.Task.Command.Result
  alias Draught.CLI.Writer

  @doc "Runs one anonymous task command and emits its terminal result."
  @spec run(Command.Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(%Command.Invocation{session: nil, resume: nil} = invocation, dependencies) do
    execute(invocation, dependencies)
  end

  def run(%Command.Invocation{} = invocation, dependencies) do
    invocation.output
    |> Output.persistent_sessions_unavailable()
    |> Writer.emit(:stderr, :session, dependencies)
  end

  defp execute(invocation, %Dependencies{} = dependencies) do
    case Loader.load(invocation, dependencies.system) do
      {:ok, configuration, workspace} ->
        result = Task.run(invocation.prompt, configuration, workspace, dependencies.task)
        Result.emit(result, invocation, dependencies)

      {:error, %Error{} = error} ->
        error
        |> Output.configuration_error(invocation.output)
        |> Writer.emit(:stderr, :usage, dependencies)
    end
  end
end
