defmodule Draught.Execution.Runner.ProviderExecution.Stream do
  @moduledoc """
  Executes one bounded provider stream and relays only canonical nonterminal events.
  """

  alias Draught.Execution.BoundedTask.Stream
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Failure.Runtime
  alias Draught.Execution.Runner.ProviderExecution.Stream.EventRelay
  alias Draught.Execution.Runner.Sink
  alias Draught.Provider

  @doc "Runs one provider stream under the runner deadline and output budget."
  @spec run(Configuration.t(), Draught.Provider.Request.t(), pos_integer()) ::
          Draught.Provider.provider_result(Draught.Provider.Response.t())
  def run(configuration, request, iteration) do
    effect = fn relay -> invoke(configuration, request, relay) end
    sink = fn event -> Sink.emit(configuration.sink, {:provider_event, iteration, event}) end

    Stream.run(
      effect,
      sink,
      configuration.limits.provider_timeout_ms,
      configuration.limits.max_output_bytes,
      Runtime.provider_timeout(),
      Runtime.provider_crashed(),
      Runtime.provider_output_too_large()
    )
  end

  defp invoke(configuration, request, relay) do
    Provider.stream(configuration.provider, request, fn event ->
      EventRelay.emit(event, relay)
    end)
  end
end
