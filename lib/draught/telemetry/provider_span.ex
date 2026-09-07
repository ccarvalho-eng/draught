defmodule Draught.Telemetry.ProviderSpan do
  @moduledoc """
  Instruments provider boundary calls with the standard request span.

  The span records only the operation, bounded usage measurements, and a
  canonical outcome so provider responses do not enter telemetry metadata.
  """

  alias Draught.Telemetry.Measurements
  alias Draught.Telemetry.Outcome
  alias Draught.Telemetry.Span

  @prefix [:draught, :provider, :request]

  @type operation :: :capabilities | :complete | :stream

  @doc "Runs one provider boundary operation inside a sanitized span."
  @spec run(operation(), (-> result)) :: result when result: term()
  def run(operation, function) when operation in [:capabilities, :complete, :stream] do
    metadata = %{operation: operation}

    Span.run(@prefix, metadata, function, fn result ->
      {Measurements.usage(result), Outcome.result(result)}
    end)
  end
end
