defmodule Draught.Telemetry.Span.Guard do
  @moduledoc """
  Enforces single completion and owner-lifetime handling for telemetry spans.

  A monitor process owns terminal emission. If the calling process exits before
  closing the span, the guard emits an exception event on its behalf.
  """

  alias Draught.Telemetry.Measurements
  alias Draught.Telemetry.Span.Handle

  @type event_prefix :: [atom()]

  @doc "Opens a span owned by a monitor process."
  @spec open(event_prefix(), map()) :: Handle.t()
  def open(prefix, metadata) do
    owner = self()
    token = make_ref()
    started_at = System.monotonic_time()
    execute(prefix, :start, Measurements.start(), metadata)

    guard =
      spawn(fn ->
        monitor(owner, token, prefix, metadata, started_at)
      end)

    Handle.new(guard, token)
  end

  @doc "Emits the single normal terminal event for a guarded span."
  @spec stop(Handle.t(), map(), map()) :: :ok
  def stop(%Handle{} = handle, measurements, metadata) do
    finish(handle, {:stop, measurements, metadata})
  end

  @doc "Emits the single explicit exception event for a guarded span."
  @spec exception(Handle.t(), map(), :error | :exit | :throw) :: :ok
  def exception(%Handle{} = handle, metadata, kind) do
    finish(handle, {:exception, metadata, kind})
  end

  defp monitor(owner, token, prefix, metadata, started_at) do
    reference = Process.monitor(owner)
    await(owner, reference, token, prefix, metadata, started_at)
  end

  defp await(owner, reference, token, prefix, start_metadata, started_at) do
    receive do
      {:finish, ^owner, ^token, {:stop, measurements, metadata}} ->
        complete(prefix, :stop, started_at, measurements, metadata)
        acknowledge(owner, token, reference)

      {:finish, ^owner, ^token, {:exception, metadata, kind}} ->
        complete_exception(prefix, started_at, metadata, kind)
        acknowledge(owner, token, reference)

      {:DOWN, ^reference, :process, ^owner, _reason} ->
        complete_exception(prefix, started_at, start_metadata, :exit)

      _message ->
        await(owner, reference, token, prefix, start_metadata, started_at)
    end
  end

  defp finish(%Handle{guard: guard, token: token}, completion) do
    send(guard, {:finish, self(), token, completion})

    receive do
      {:span_finished, ^token} -> :ok
    end
  end

  defp complete(prefix, suffix, started_at, measurements, metadata) do
    bounded =
      started_at
      |> Measurements.completion()
      |> Map.merge(measurements)

    execute(prefix, suffix, bounded, metadata)
  end

  defp complete_exception(prefix, started_at, metadata, kind) do
    safe_metadata = Map.merge(metadata, %{exception_kind: kind, outcome: :exception})
    complete(prefix, :exception, started_at, %{}, safe_metadata)
  end

  defp acknowledge(owner, token, reference) do
    Process.demonitor(reference, [:flush])
    send(owner, {:span_finished, token})
  end

  defp execute(prefix, suffix, measurements, metadata) do
    prefix
    |> event(suffix)
    |> :telemetry.execute(measurements, metadata)
  end

  defp event([namespace, domain, operation], suffix) do
    [namespace, domain, operation, suffix]
  end
end
