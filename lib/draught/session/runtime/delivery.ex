defmodule Draught.Session.Runtime.Delivery do
  @moduledoc false

  alias Draught.Session.Event

  @doc "Delivers one tagged session event to a subscriber process."
  @spec event(pid(), String.t(), Event.t()) :: :ok
  def event(subscriber, session_id, event) do
    send(subscriber, {:draught_session, session_id, event})
    :ok
  end
end
