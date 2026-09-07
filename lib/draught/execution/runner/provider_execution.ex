defmodule Draught.Execution.Runner.ProviderExecution do
  @moduledoc """
  Executes one provider completion within runner resource limits.

  The provider call is supervised and time-bounded, and successful canonical
  responses are rejected before retention when they exceed the output limit.
  """

  alias Draught.Execution.BoundedTask
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Execution.Runner.Output
  alias Draught.Provider
  alias Draught.Provider.Request
  alias Draught.Provider.Response

  @doc "Runs one provider completion within the configured bounds."
  @spec complete(Configuration.t(), Request.t()) ::
          {:ok, Response.t()} | {:error, term()}
  def complete(configuration, request) do
    effect = fn -> Provider.complete(configuration.provider, request) end

    effect
    |> BoundedTask.run(
      configuration.limits.provider_timeout_ms,
      Runtime.provider_timeout(),
      Runtime.provider_crashed()
    )
    |> Output.bound(configuration.limits.max_output_bytes)
  end
end
