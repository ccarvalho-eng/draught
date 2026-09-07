defmodule Draught.Tool.Builtin.WebSearch.Executor do
  @moduledoc false

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Approval
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Web.Capability
  alias Draught.Web.Failure
  alias Draught.Web.Search

  @maximum_query_bytes 1_024

  @impl Draught.Tool.Executor
  def execute(%Call{arguments: %{"query" => query}} = call, %Context{} = context, _configuration) do
    with :ok <- enabled(context.web),
         :ok <- query(query),
         :ok <-
           Approval.authorize(call, context, :network, "web search", query) do
      Search.run(context.web, query, context.policy.max_output_bytes)
    end
  end

  defp enabled(%Capability{} = capability) do
    capability
    |> Capability.enabled?(:search)
    |> enabled_result()
  end

  defp query(value)
       when is_binary(value) and byte_size(value) > 0 and
              byte_size(value) <= @maximum_query_bytes do
    :ok
  end

  defp query(_value) do
    {:error, Failure.invalid_result()}
  end

  defp enabled_result(true) do
    :ok
  end

  defp enabled_result(false) do
    {:error, Failure.disabled(:search)}
  end
end
