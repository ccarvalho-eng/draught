defmodule Draught.CLI.EntryPoint.Dispatch do
  @moduledoc """
  Routes a parsed operating-system invocation through its terminal boundary.
  """

  alias Draught.CLI
  alias Draught.CLI.Command
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies

  @doc "Parses and runs one invocation through the selected CLI boundary."
  @spec run([String.t()], Dependencies.t()) :: non_neg_integer()
  def run(arguments, %Dependencies{} = dependencies) do
    arguments
    |> Command.parse()
    |> dispatch(dependencies)
  end

  defp dispatch({:ok, %Invocation{command: :interactive, output: :text}} = parsed, dependencies) do
    CLI.run_parsed(parsed, dependencies)
  end

  defp dispatch(parsed, dependencies) do
    CLI.run_parsed(parsed, dependencies)
  end
end
