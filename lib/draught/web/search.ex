defmodule Draught.Web.Search do
  @moduledoc """
  Executes an injected search adapter and returns bounded untrusted output.
  """

  alias Draught.Web.Capability
  alias Draught.Web.Execution
  alias Draught.Web.Failure
  alias Draught.Web.Output
  alias Draught.Web.Search.Result
  alias Draught.Web.ToolResult

  @doc "Searches under the explicit capability and effective policy."
  @spec run(Capability.t(), String.t(), pos_integer()) :: Draught.Tool.Executor.result()
  def run(%Capability{} = capability, query, maximum_output_bytes) do
    case Capability.fetch_adapter(capability, :search) do
      {:ok, {module, configuration}} ->
        execute(module, query, capability, configuration, maximum_output_bytes)

      :error ->
        {:error, Failure.disabled(:search)}
    end
  end

  defp execute(module, query, capability, configuration, maximum_output_bytes) do
    fn -> module.search(query, capability.policy, configuration) end
    |> Execution.run(capability.policy)
    |> normalize(capability, maximum_output_bytes)
  end

  defp normalize({:ok, items}, capability, maximum_output_bytes) do
    with {:ok, result} <- Result.new(items, capability.policy),
         {:ok, content, sources} <- Output.search(result, maximum_output_bytes) do
      ToolResult.output(content, sources, maximum_output_bytes)
    else
      {:error, :too_large} -> {:error, Failure.response_too_large()}
      _result -> {:error, Failure.invalid_result()}
    end
  end

  defp normalize({:error, error}, _capability, _maximum_output_bytes) do
    ToolResult.error(error)
  end

  defp normalize(_result, _capability, _maximum_output_bytes) do
    {:error, Failure.invalid_result()}
  end
end
