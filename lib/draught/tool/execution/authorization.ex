defmodule Draught.Tool.Execution.Authorization do
  @moduledoc false

  alias Draught.Tool.Execution.Failure
  alias Draught.Tool.Execution.Policy

  @doc "Checks whether a tool risk is allowed by an execution policy."
  @spec check(Draught.Tool.Risk.t(), Policy.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def check(risk, %Policy{allowed_risks: allowed_risks}) do
    risk
    |> then(&(&1 in allowed_risks))
    |> result()
  end

  defp result(true) do
    :ok
  end

  defp result(false) do
    {:error, Failure.tool_risk_denied()}
  end
end
