defmodule Draught.Telemetry.Capture do
  @moduledoc """
  Attaches an isolated telemetry capture handler for deterministic tests.
  """

  alias Draught.Telemetry

  @type token :: reference()
  @type attach_error :: :invalid_events | :invalid_owner | :telemetry_attach_failed

  @doc "Attaches a handler that sends all Draught events to the calling process."
  @spec attach(pid()) :: {:ok, token()} | {:error, attach_error()}
  def attach(owner) do
    attach(owner, Telemetry.events())
  end

  @doc "Attaches a handler for a selected subset of known Draught events."
  @spec attach(pid(), [Telemetry.event_name()]) ::
          {:ok, token()} | {:error, attach_error()}
  def attach(owner, events) when is_pid(owner) and is_list(events) do
    with :ok <- validate_events(events) do
      attach_handler(owner, events)
    end
  end

  def attach(_owner, _events) do
    {:error, :invalid_owner}
  end

  @doc "Detaches a handler previously returned by `attach/1` or `attach/2`."
  @spec detach(token()) :: :ok
  def detach(token) when is_reference(token) do
    token
    |> handler_id()
    |> :telemetry.detach()
  end

  @doc false
  @spec handle_event(Telemetry.event_name(), map(), map(), {pid(), token()}) :: term()
  def handle_event(event, measurements, metadata, {owner, token}) do
    send(owner, {__MODULE__, token, event, measurements, metadata})
  end

  defp validate_events(events) do
    known = MapSet.new(Telemetry.events())

    events
    |> Enum.all?(&MapSet.member?(known, &1))
    |> events_result()
  end

  defp events_result(true) do
    :ok
  end

  defp events_result(false) do
    {:error, :invalid_events}
  end

  defp attach_handler(owner, events) do
    token = make_ref()
    configuration = {owner, token}
    id = handler_id(token)
    handler = &__MODULE__.handle_event/4

    case :telemetry.attach_many(id, events, handler, configuration) do
      :ok -> {:ok, token}
      {:error, _reason} -> {:error, :telemetry_attach_failed}
    end
  end

  defp handler_id(token) do
    {__MODULE__, token}
  end
end
