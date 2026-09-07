defmodule Draught.Session.Runtime.Delivery do
  @moduledoc """
  Delivers versioned session events to a validated subscriber process.
  """

  alias Draught.Session.Event

  @doc "Delivers one tagged session event to a subscriber process."
  @spec event(pid(), String.t(), Event.t()) :: :ok
  def event(subscriber, session_id, event) do
    send(subscriber, {:draught_session, session_id, event})
    :ok
  end

  @doc "Delivers one tagged runner event carrying its single-use acknowledgement reference."
  @spec acknowledged_event(pid(), String.t(), Event.t(), reference()) :: :ok
  def acknowledged_event(subscriber, session_id, event, acknowledgement) do
    send(
      subscriber,
      {:draught_session, session_id, append_acknowledgement(event, acknowledgement)}
    )

    :ok
  end

  defp append_acknowledgement({:runner, turn_id, event}, acknowledgement) do
    {:runner, turn_id, event, acknowledgement}
  end
end
