defmodule Draught.Telemetry do
  @moduledoc """
  Defines Draught telemetry event names and measurement bounds.

  Draught emits events but does not install a reporter or telemetry backend.
  """

  @maximum_count 1_000_000_000_000

  @session_events [
    [:draught, :session, :turn, :start],
    [:draught, :session, :turn, :stop],
    [:draught, :session, :turn, :exception]
  ]
  @provider_events [
    [:draught, :provider, :request, :start],
    [:draught, :provider, :request, :stop],
    [:draught, :provider, :request, :exception]
  ]
  @tool_events [
    [:draught, :tool, :execution, :start],
    [:draught, :tool, :execution, :stop],
    [:draught, :tool, :execution, :exception]
  ]
  @events @session_events ++ @provider_events ++ @tool_events

  @type domain :: :provider | :session | :tool
  @type event_name :: [atom()]

  @doc "Returns every telemetry event emitted by Draught."
  @spec events() :: [event_name()]
  def events do
    @events
  end

  @doc "Returns telemetry events for one closed runtime domain."
  @spec events(domain()) :: [event_name()]
  def events(:provider) do
    @provider_events
  end

  def events(:session) do
    @session_events
  end

  def events(:tool) do
    @tool_events
  end

  @doc "Returns the upper bound applied to count and token measurements."
  @spec maximum_count() :: pos_integer()
  def maximum_count do
    @maximum_count
  end
end
