defmodule Draught.Application do
  @moduledoc """
  Starts the supervisors used by Draught sessions and their bounded work.
  """

  use Application

  @impl Application
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Draught.Execution.TaskSupervisor},
      Draught.CLI.Interactive.Terminal.Input,
      Draught.Tool.Mutation.Queue,
      Draught.Session.Supervisor
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: Draught.Supervisor
    )
  end
end
