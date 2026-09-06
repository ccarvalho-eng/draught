defmodule Draught.Tool.Execution.Invocation do
  @moduledoc """
  Applies registry, policy, schema, and executor boundaries to one call.
  """

  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Outcome
  alias Draught.Tool.Execution.Preparation
  alias Draught.Tool.Executor.Dispatch
  alias Draught.Tool.Registry

  @doc "Runs one canonical call and returns a canonical result for every expected outcome."
  @spec run(Registry.t(), Call.t(), Context.t()) :: Draught.Tool.Result.t()
  def run(%Registry{} = registry, %Call{} = call, %Context{} = context) do
    registry
    |> Preparation.prepare(call, context)
    |> dispatch(call, context)
    |> Outcome.from_execution(call)
  end

  defp dispatch({:ok, definition}, call, context) do
    Dispatch.execute(definition.executor, call, context)
  end

  defp dispatch({:error, _error} = result, _call, _context) do
    result
  end
end
