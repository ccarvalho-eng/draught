defmodule Draught.Session.Runtime.ActiveTurn do
  @moduledoc """
  Represents the monitored worker and timeout state for one active session turn.
  """

  alias Draught.Session.Runtime.Delivery

  @enforce_keys [:delivery, :id, :subscriber, :task, :telemetry_span, :timer, :token]
  defstruct [:delivery, :id, :pending, :subscriber, :task, :telemetry_span, :timer, :token]

  @type delivery :: :acknowledged | :asynchronous
  @type pending :: {reference(), GenServer.from()} | nil

  @type t :: %__MODULE__{
          delivery: delivery(),
          id: pos_integer(),
          pending: pending(),
          subscriber: pid(),
          task: Task.t(),
          telemetry_span: Draught.Telemetry.Span.handle(),
          timer: reference() | nil,
          token: reference()
        }

  @doc "Builds the runtime ownership value for one active turn."
  @spec new(
          pos_integer(),
          pid(),
          Task.t(),
          Draught.Telemetry.Span.handle(),
          reference() | nil,
          reference(),
          delivery()
        ) :: t()
  def new(id, subscriber, task, telemetry_span, timer, token, delivery) do
    %__MODULE__{
      delivery: delivery,
      id: id,
      subscriber: subscriber,
      task: task,
      telemetry_span: telemetry_span,
      timer: timer,
      token: token
    }
  end

  @doc "Delivers one event to this turn's subscriber."
  @spec deliver(t(), String.t(), Draught.Session.Event.t()) :: :ok
  def deliver(%__MODULE__{} = active, session_id, event) do
    Delivery.event(active.subscriber, session_id, event)
  end

  @doc "Delivers a runner event according to the subscriber's delivery contract."
  @spec deliver_runner(t(), String.t(), Draught.Session.Event.t(), GenServer.from()) ::
          {:delivered, t()} | {:pending, t()}
  def deliver_runner(%__MODULE__{delivery: :asynchronous} = active, session_id, event, _from) do
    :ok = Delivery.event(active.subscriber, session_id, event)
    {:delivered, active}
  end

  def deliver_runner(
        %__MODULE__{delivery: :acknowledged, pending: nil} = active,
        session_id,
        event,
        from
      ) do
    acknowledgement = make_ref()
    :ok = Delivery.acknowledged_event(active.subscriber, session_id, event, acknowledgement)
    {:pending, %{active | pending: {acknowledgement, from}}}
  end

  @doc "Resolves the matching pending runner delivery and clears its authority."
  @spec acknowledge(t(), reference(), :ok | :halt) :: {:ok, t()} | :stale
  def acknowledge(%__MODULE__{pending: {acknowledgement, from}} = active, acknowledgement, result) do
    GenServer.reply(from, result)
    {:ok, %{active | pending: nil}}
  end

  def acknowledge(%__MODULE__{}, _acknowledgement, _result) do
    :stale
  end

  @doc "Halts and clears any pending runner delivery before terminal transition."
  @spec halt_pending(t()) :: t()
  def halt_pending(%__MODULE__{pending: nil} = active) do
    active
  end

  def halt_pending(%__MODULE__{pending: {_acknowledgement, from}} = active) do
    GenServer.reply(from, :halt)
    %{active | pending: nil}
  end
end
