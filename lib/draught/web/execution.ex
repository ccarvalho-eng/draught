defmodule Draught.Web.Execution do
  @moduledoc """
  Runs web effects within the configured total operation deadline.

  Timeouts and unexpected task failures are converted to normalized web errors at
  this boundary.
  """

  alias Draught.Execution.BoundedTask
  alias Draught.Web.Failure
  alias Draught.Web.Policy

  @doc "Runs one web adapter inside the effective total operation deadline."
  @spec run((-> term()), Policy.t()) :: term()
  def run(effect, %Policy{} = policy) when is_function(effect, 0) do
    BoundedTask.run(
      effect,
      policy.total_timeout_ms,
      Failure.timeout(),
      Failure.request_failed()
    )
  end
end
