defmodule Draught.CLI.Task.Command.Result do
  @moduledoc false

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Task.Output
  alias Draught.CLI.Writer
  alias Draught.Error.Normalized
  alias Draught.Validation.Error

  @doc "Renders a task result and returns its stable operating-system status."
  @spec emit(Draught.CLI.Task.result(), Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def emit({:ok, response}, invocation, dependencies) do
    response
    |> Output.success(invocation.output)
    |> Writer.emit(:stdout, :success, dependencies)
  end

  def emit({:error, category, %Normalized{} = error}, invocation, dependencies) do
    error
    |> Output.error(category, invocation.output)
    |> Writer.emit(:stderr, exit_category(category, error), dependencies)
  end

  def emit({:error, category, %Error{}}, invocation, dependencies) do
    category
    |> Draught.CLI.Output.task_setup_error(invocation.output)
    |> Writer.emit(:stderr, exit_category(category, nil), dependencies)
  end

  defp exit_category(:provider, _error) do
    :provider
  end

  defp exit_category(:session, _error) do
    :session
  end

  defp exit_category(:execution, %Normalized{kind: :cancellation}) do
    :interrupted
  end

  defp exit_category(:execution, _error) do
    :execution
  end
end
