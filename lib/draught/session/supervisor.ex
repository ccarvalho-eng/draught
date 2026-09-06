defmodule Draught.Session.Supervisor do
  @moduledoc """
  Supervises the registry and dynamic supervisor that own Draught sessions.

  A registry failure restarts the dynamic supervisor so live session processes
  cannot survive with missing registrations.
  """

  use Supervisor

  @doc "Starts the session supervision boundary."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl Supervisor
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(_options) do
    children = [
      {Registry, keys: :unique, name: Draught.Session.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Draught.Session.DynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
