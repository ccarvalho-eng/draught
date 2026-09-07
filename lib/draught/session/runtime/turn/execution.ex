defmodule Draught.Session.Runtime.Turn.Execution do
  @moduledoc """
  Rebuilds and executes one owner-guarded runner configuration for a session turn.
  """

  alias Draught.Execution.BoundedTask.OwnerGuard
  alias Draught.Execution.Runner
  alias Draught.Session.Settings

  @doc "Runs one request with the session-owned event sink."
  @spec run(pid(), Settings.t(), term(), Draught.Execution.Runner.Event.sink()) :: Runner.result()
  def run(session, settings, request, sink) do
    :ok = OwnerGuard.protect(session)

    settings.runner
    |> Map.from_struct()
    |> Map.put(:sink, sink)
    |> Runner.run(request)
  end
end
