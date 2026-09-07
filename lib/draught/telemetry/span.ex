defmodule Draught.Telemetry.Span do
  @moduledoc false

  alias Draught.Telemetry.Span.Guard
  alias Draught.Telemetry.Span.Handle

  @type event_prefix :: [atom()]
  @type handle :: Handle.t()

  @doc "Runs one function inside a sanitized start, stop, and exception span."
  @spec run(event_prefix(), map(), (-> result), (result -> {map(), map()})) :: result
        when result: term()
  def run(prefix, start_metadata, function, projector)
      when is_function(function, 0) and is_function(projector, 1) do
    handle = start(prefix, start_metadata)

    try do
      result = function.()
      {measurements, stop_metadata} = projector.(result)
      :ok = stop(handle, measurements, Map.merge(start_metadata, stop_metadata))
      result
    catch
      kind, reason ->
        :ok = exception(handle, start_metadata, kind)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  @doc "Starts a manually coordinated sanitized span."
  @spec start(event_prefix(), map()) :: handle()
  def start(prefix, metadata) do
    Guard.open(prefix, metadata)
  end

  @doc "Stops a manually coordinated sanitized span."
  @spec stop(handle(), map(), map()) :: :ok
  def stop(%Handle{} = handle, measurements, metadata) do
    Guard.stop(handle, measurements, metadata)
  end

  @doc "Emits a sanitized exceptional completion without a reason or stack trace."
  @spec exception(handle(), map(), :error | :exit | :throw) :: :ok
  def exception(%Handle{} = handle, metadata, kind) do
    Guard.exception(handle, metadata, kind)
  end
end
