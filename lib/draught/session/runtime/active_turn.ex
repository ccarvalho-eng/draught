defmodule Draught.Session.Runtime.ActiveTurn do
  @moduledoc false

  alias Draught.Session.Runtime.Delivery

  @enforce_keys [:id, :subscriber, :task, :timer, :token]
  defstruct [:id, :subscriber, :task, :timer, :token]

  @type t :: %__MODULE__{
          id: pos_integer(),
          subscriber: pid(),
          task: Task.t(),
          timer: reference(),
          token: reference()
        }

  @doc "Builds the runtime ownership value for one active turn."
  @spec new(pos_integer(), pid(), Task.t(), reference(), reference()) :: t()
  def new(id, subscriber, task, timer, token) do
    %__MODULE__{id: id, subscriber: subscriber, task: task, timer: timer, token: token}
  end

  @doc "Delivers one event to this turn's subscriber."
  @spec deliver(t(), String.t(), Draught.Session.Event.t()) :: :ok
  def deliver(%__MODULE__{} = active, session_id, event) do
    Delivery.event(active.subscriber, session_id, event)
  end
end
