defmodule Draught.CLI.Task.Stream.Indicator do
  @moduledoc """
  Advances the pure timing and rendering state of a TTY activity indicator.

  The caller owns time and output effects. Cursor controls are produced only
  when the state was explicitly enabled after terminal capability checks.
  """

  alias Draught.CLI.Task.Stream.Indicator.State

  @frames ["|", "/", "-", "\\"]
  @clear "\r\e[2K"

  @type action :: {:emit, State.t(), iodata()} | {:skip, State.t()}

  @doc "Arms an idle indicator without rendering immediately."
  @spec start(State.t(), integer()) :: State.t()
  def start(%State{enabled: true, phase: :idle} = state, now) when is_integer(now) do
    %{state | next_at: now + state.delay_ms, phase: :waiting}
  end

  def start(%State{} = state, _now) do
    state
  end

  @doc "Returns the bounded receive timeout until the next indicator frame."
  @spec wait_timeout(State.t(), non_neg_integer(), integer()) :: non_neg_integer()
  def wait_timeout(%State{enabled: true, next_at: next_at}, maximum, now)
      when is_integer(next_at) and is_integer(maximum) and maximum >= 0 and is_integer(now) do
    min(max(next_at - now, 0), maximum)
  end

  def wait_timeout(%State{}, maximum, _now) when is_integer(maximum) and maximum >= 0 do
    maximum
  end

  @doc "Renders the next frame when due and advances its deadline."
  @spec tick(State.t(), integer()) :: action()
  def tick(%State{enabled: true, next_at: next_at} = state, now)
      when is_integer(next_at) and is_integer(now) and now >= next_at do
    frame = Enum.at(@frames, rem(state.frame, length(@frames)))
    content = [@clear, frame, " Working"]

    emit_frame(state, content, now)
  end

  def tick(%State{} = state, _now) do
    {:skip, state}
  end

  @doc "Stops the indicator and clears a rendered frame when necessary."
  @spec clear(State.t()) :: action()
  def clear(%State{phase: :visible} = state) do
    {:emit, record_bytes(idle(state), @clear), @clear}
  end

  def clear(%State{} = state) do
    {:skip, idle(state)}
  end

  defp emit_frame(state, content, now) do
    bytes = IO.iodata_length(content)
    clear_bytes = byte_size(@clear)
    available = state.emitted_bytes + bytes + clear_bytes <= state.maximum_bytes
    emit_frame(available, state, content, bytes, now)
  end

  defp emit_frame(true, state, content, bytes, now) do
    {:emit, visible(state, bytes, now), content}
  end

  defp emit_frame(false, state, _content, _bytes, _now) do
    exhaust(state)
  end

  defp visible(state, bytes, now) do
    %{
      state
      | emitted_bytes: state.emitted_bytes + bytes,
        frame: state.frame + 1,
        next_at: now + state.interval_ms,
        phase: :visible
    }
  end

  defp exhaust(%State{phase: :visible} = state) do
    idle_state = idle(state)
    disabled = disable(idle_state)
    {:emit, record_bytes(disabled, @clear), @clear}
  end

  defp exhaust(%State{} = state) do
    state = idle(state)
    {:skip, disable(state)}
  end

  defp record_bytes(state, content) do
    %{state | emitted_bytes: state.emitted_bytes + IO.iodata_length(content)}
  end

  defp disable(state) do
    %{state | enabled: false}
  end

  defp idle(state) do
    %{state | next_at: nil, phase: :idle}
  end
end
