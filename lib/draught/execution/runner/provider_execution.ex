defmodule Draught.Execution.Runner.ProviderExecution do
  @moduledoc """
  Executes one provider request within runner resource limits.

  Completion and streaming modes share the same supervised deadline and final
  response limit. Streaming additionally relays nonterminal events in order and
  bounds their cumulative transient size before delivery.
  """

  alias Draught.Execution.BoundedTask
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Execution.Runner.Output
  alias Draught.Execution.Runner.ProviderExecution.Stream
  alias Draught.Provider
  alias Draught.Provider.Request
  alias Draught.Provider.Response

  @doc "Runs one provider request in the configured execution mode and bounds."
  @spec run(Configuration.t(), Request.t(), pos_integer()) ::
          {:ok, Response.t()} | {:error, term()}
  def run(%Configuration{provider_mode: :complete} = configuration, request, _iteration) do
    effect = fn -> Provider.complete(configuration.provider, request) end

    effect
    |> BoundedTask.run(
      configuration.limits.provider_timeout_ms,
      Runtime.provider_timeout(),
      Runtime.provider_crashed()
    )
    |> Output.bound(configuration.limits.max_output_bytes)
  end

  def run(%Configuration{provider_mode: :stream} = configuration, request, iteration) do
    configuration
    |> Stream.run(request, iteration)
    |> Output.bound(configuration.limits.max_output_bytes)
  end
end
