defmodule Draught.CLI do
  @moduledoc """
  Executes bounded CLI intents through explicit effect adapters.
  """

  alias Draught.CLI.Command
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Router

  @doc "Runs one CLI invocation and returns its stable operating-system status."
  @spec run(term(), Dependencies.t()) :: non_neg_integer()
  def run(arguments, %Dependencies{} = dependencies) do
    arguments
    |> Command.parse()
    |> Router.dispatch(dependencies)
  end
end
