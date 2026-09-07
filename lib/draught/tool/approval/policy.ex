defmodule Draught.Tool.Approval.Policy do
  @moduledoc """
  Defines the effect boundary for tool approval decisions.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Request

  @type config :: term()
  @type result :: {:ok, Decision.t()} | {:error, Normalized.t()}

  @doc "Decides whether one sanitized tool request may proceed."
  @callback decide(Request.t(), config()) :: result()
end
