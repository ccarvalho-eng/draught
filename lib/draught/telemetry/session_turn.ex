defmodule Draught.Telemetry.SessionTurn do
  @moduledoc false

  alias Draught.Telemetry.Measurements
  alias Draught.Telemetry.Outcome
  alias Draught.Telemetry.Span

  @prefix [:draught, :session, :turn]

  @doc "Starts one asynchronously coordinated session-turn span."
  @spec start() :: Span.handle()
  def start do
    Span.start(@prefix, %{})
  end

  @doc "Stops one session-turn span with a canonical outcome."
  @spec stop(Span.handle(), term()) :: :ok
  def stop(handle, outcome) do
    Span.stop(handle, Measurements.usage(outcome), Outcome.result(outcome))
  end

  @doc "Marks one session-turn span as exceptionally terminated."
  @spec exception(Span.handle(), :error | :exit | :throw) :: :ok
  def exception(handle, kind) do
    Span.exception(handle, %{}, kind)
  end
end
