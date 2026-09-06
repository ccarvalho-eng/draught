defmodule Draught.Tool.Executor do
  @moduledoc """
  Defines the effect boundary implemented by executable tools.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context

  @type config :: term()
  @type result :: {:ok, String.t()} | {:error, Normalized.t()}

  @doc "Executes a canonical call inside an explicit execution context."
  @callback execute(Call.t(), Context.t(), config()) :: result()
end
