defmodule Draught.Execution.Runner.Output do
  @moduledoc false

  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Provider.Response

  @doc "Rejects retained canonical provider values above the runner output limit."
  @spec bound({:ok, Response.t()} | {:error, term()}, pos_integer()) ::
          {:ok, Response.t()} | {:error, term()}
  def bound({:ok, %Response{} = response} = result, maximum_bytes) do
    result(:erlang.external_size(response) <= maximum_bytes, result)
  end

  def bound({:error, _error} = result, _maximum_bytes) do
    result
  end

  defp result(true, result) do
    result
  end

  defp result(false, _result) do
    {:error, Runtime.provider_output_too_large()}
  end
end
