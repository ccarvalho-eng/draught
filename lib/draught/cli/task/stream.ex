defmodule Draught.CLI.Task.Stream do
  @moduledoc """
  Coordinates pure event projection, bounded rendering, and ordered CLI writes.

  The silent variant preserves the application-facing task APIs. A visible
  stream is owned by one CLI invocation and is threaded through execution.
  """

  alias Draught.CLI.Task.Stream.Emitter
  alias Draught.CLI.Task.Stream.Indicator
  alias Draught.CLI.Task.Stream.Indicator.State
  alias Draught.CLI.Task.Stream.Output
  alias Draught.CLI.Task.Stream.Projector

  @default_maximum_bytes 1024 * 1024
  @minimum_indicator_columns 40

  @enforce_keys [:mode]
  defstruct [:indicator, :projector, :system, mode: :silent, writable: true]

  @type t :: %__MODULE__{
          mode: :silent | :visible,
          indicator: State.t() | nil,
          projector: Draught.CLI.Task.Stream.Projector.State.t() | nil,
          system: {module(), term()} | nil,
          writable: boolean()
        }

  @doc "Builds one visible CLI stream for text or JSONL output."
  @spec new(:jsonl | :text, {module(), term()}, keyword()) :: t()
  def new(format, system, options \\ []) do
    maximum_bytes = Keyword.get(options, :maximum_bytes, @default_maximum_bytes)
    indicator_enabled = indicator_enabled?(format, system, Keyword.get(options, :color, :auto))

    %__MODULE__{
      indicator: State.new(indicator_enabled, options),
      mode: :visible,
      projector: Draught.CLI.Task.Stream.Projector.State.new(format, maximum_bytes),
      system: system
    }
  end

  @doc "Builds a no-output observer for application-facing task calls."
  @spec silent() :: t()
  def silent do
    %__MODULE__{mode: :silent}
  end

  @doc "Arms the terminal activity indicator after a turn starts."
  @spec start(t()) :: t()
  def start(%__MODULE__{mode: :visible, indicator: indicator} = stream) do
    %{stream | indicator: Indicator.start(indicator, now())}
  end

  def start(%__MODULE__{} = stream) do
    stream
  end

  @doc "Returns the next bounded wait interval for execution or indicator progress."
  @spec wait_timeout(t(), non_neg_integer()) :: non_neg_integer()
  def wait_timeout(%__MODULE__{mode: :visible, indicator: indicator}, maximum) do
    Indicator.wait_timeout(indicator, maximum, now())
  end

  def wait_timeout(%__MODULE__{}, maximum) do
    maximum
  end

  @doc "Advances and writes an activity frame when its deadline has elapsed."
  @spec tick(t()) :: {:ok, t()} | {:error, :write, t()}
  def tick(%__MODULE__{mode: :visible, writable: true} = stream) do
    indicator_action(stream, Indicator.tick(stream.indicator, now()))
  end

  def tick(%__MODULE__{mode: :visible} = stream) do
    {:error, :write, stream}
  end

  def tick(%__MODULE__{} = stream) do
    {:ok, stream}
  end

  @doc "Projects and emits one runner event, returning the updated stream."
  @spec observe(t(), Draught.Execution.Runner.Event.t()) ::
          {:ok, t()} | {:error, :encoding | :invalid_event | :output_limit | :write, t()}
  def observe(%__MODULE__{mode: :silent} = stream, _event) do
    {:ok, stream}
  end

  def observe(%__MODULE__{mode: :visible, writable: true} = stream, event) do
    case Projector.project(stream.projector, event) do
      {:skip, projector} -> {:ok, %{stream | projector: projector}}
      {:emit, projector, projected} -> clear_and_emit(stream, projector, projected, :bounded)
      {:error, :invalid_event} -> {:error, :invalid_event, stream}
    end
  end

  def observe(%__MODULE__{} = stream, _event) do
    {:error, :write, stream}
  end

  @doc "Projects and writes exactly one terminal task outcome."
  @spec finish(t(), Draught.CLI.Task.result()) ::
          {:ok, t()}
          | {:error, :encoding | :inconsistent_stream | :invalid_event | :output_limit | :write,
             t()}
  def finish(%__MODULE__{mode: :silent} = stream, _result) do
    {:ok, stream}
  end

  def finish(%__MODULE__{mode: :visible, writable: true} = stream, result) do
    case Projector.finish(stream.projector, result) do
      {:emit, projector, projected} ->
        clear_and_emit(stream, projector, projected, :terminal)

      {:error, reason} when reason in [:inconsistent_stream, :invalid_event] ->
        {:error, reason, stream}
    end
  end

  def finish(%__MODULE__{} = stream, _result) do
    {:error, :write, stream}
  end

  defp clear_and_emit(stream, projector, event, mode) do
    case clear_indicator(stream) do
      {:ok, cleared} -> emit(cleared, projector, event, mode)
      {:error, :write, failed} -> {:error, :write, failed}
    end
  end

  defp clear_indicator(stream) do
    indicator_action(stream, Indicator.clear(stream.indicator))
  end

  defp indicator_action(stream, {:skip, indicator}) do
    {:ok, %{stream | indicator: indicator}}
  end

  defp indicator_action(stream, {:emit, indicator, content}) do
    case Emitter.write(stream.system, :stdout, content) do
      :ok -> {:ok, %{stream | indicator: indicator}}
      {:error, _reason} -> {:error, :write, %{stream | writable: false}}
    end
  end

  defp emit(stream, projector, event, mode) do
    case Output.emit(stream.system, projector, event, mode) do
      {:ok, recorded} -> {:ok, %{stream | projector: recorded}}
      {:error, reason} when reason in [:encoding, :output_limit] -> {:error, reason, stream}
      {:error, :write} -> {:error, :write, %{stream | writable: false}}
    end
  end

  defp indicator_enabled?(:text, {system, configuration}, color)
       when color in [:auto, :always] do
    system.tty?(:stdout, configuration) and usable_width?(system.columns(configuration))
  end

  defp indicator_enabled?(_format, _system, _color) do
    false
  end

  defp usable_width?({:ok, columns}) do
    columns >= @minimum_indicator_columns
  end

  defp usable_width?({:error, :unavailable}) do
    false
  end

  defp now do
    System.monotonic_time(:millisecond)
  end
end
