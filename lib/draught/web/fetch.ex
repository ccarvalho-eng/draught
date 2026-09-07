defmodule Draught.Web.Fetch do
  @moduledoc """
  Executes an injected fetch adapter and returns bounded untrusted output.
  """

  alias Draught.Web.Capability
  alias Draught.Web.Execution
  alias Draught.Web.Failure
  alias Draught.Web.Fetch.Response
  alias Draught.Web.Output
  alias Draught.Web.ToolResult

  @doc "Fetches one page under the explicit capability and effective policy."
  @spec run(Capability.t(), String.t(), pos_integer()) :: Draught.Tool.Executor.result()
  def run(%Capability{} = capability, url, maximum_output_bytes) do
    case Capability.fetch_adapter(capability, :fetch) do
      {:ok, {module, configuration}} ->
        execute(module, url, capability, configuration, maximum_output_bytes)

      :error ->
        {:error, Failure.disabled(:fetch)}
    end
  end

  defp execute(module, url, capability, configuration, maximum_output_bytes) do
    fn -> module.fetch(url, capability.policy, configuration) end
    |> Execution.run(capability.policy)
    |> normalize(capability, maximum_output_bytes)
  end

  defp normalize({:ok, attributes}, capability, maximum_output_bytes) do
    with {:ok, response} <- response(attributes, capability),
         {:ok, content, sources} <- Output.fetch(response, maximum_output_bytes) do
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

  defp response(%Response{} = response, capability) do
    response
    |> Map.from_struct()
    |> Response.new(capability.policy)
  end

  defp response(attributes, capability) do
    Response.new(attributes, capability.policy)
  end
end
