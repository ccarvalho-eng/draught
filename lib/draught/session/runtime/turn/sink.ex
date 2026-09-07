defmodule Draught.Session.Runtime.Turn.Sink do
  @moduledoc """
  Relays runner events synchronously to the token-scoped session boundary.
  """

  @doc "Relays one event or requests runner cancellation when the session is unavailable."
  @spec emit(pid(), reference(), Draught.Execution.Runner.Event.t()) :: :ok | :halt
  def emit(session, token, event) do
    GenServer.call(session, {:runner_event, token, event})
  catch
    :exit, _reason -> :halt
  end
end
