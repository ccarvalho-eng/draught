defmodule Draught.Provider.OpenAI.Stream.Accumulator.State do
  @moduledoc "Holds immutable, bounded state for one OpenAI-compatible provider stream."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.Accumulator.Configuration
  alias Draught.Provider.OpenAI.Stream.Accumulator.Output
  alias Draught.Provider.OpenAI.Stream.ToolCalls
  alias Draught.Provider.Usage
  alias Draught.Tool.Call

  @enforce_keys [
    :text,
    :reasoning,
    :tool_calls,
    :calls,
    :output_bytes,
    :output_fragments,
    :max_output_bytes,
    :max_output_fragments,
    :status,
    :output_emitted
  ]
  defstruct [
    :text,
    :reasoning,
    :tool_calls,
    :calls,
    :output_bytes,
    :output_fragments,
    :max_output_bytes,
    :max_output_fragments,
    :finish_reason,
    :usage,
    :status,
    :output_emitted
  ]

  @type status :: :open | :finished
  @type finish_reason :: :content_filter | :length | :other | :stop | :tool_calls
  @type t :: %__MODULE__{
          text: [String.t()],
          reasoning: [String.t()],
          tool_calls: ToolCalls.t(),
          calls: [Call.t()],
          output_bytes: non_neg_integer(),
          output_fragments: non_neg_integer(),
          max_output_bytes: pos_integer(),
          max_output_fragments: pos_integer(),
          finish_reason: finish_reason() | nil,
          usage: Usage.t() | nil,
          status: status(),
          output_emitted: boolean()
        }

  @doc "Initializes stream state from validated retention configuration."
  @spec new(Configuration.t()) :: t()
  def new(%Configuration{} = configuration) do
    %__MODULE__{
      text: [],
      reasoning: [],
      tool_calls: configuration.tool_calls,
      calls: [],
      output_bytes: 0,
      output_fragments: 0,
      max_output_bytes: configuration.max_output_bytes,
      max_output_fragments: configuration.max_output_fragments,
      status: :open,
      output_emitted: false
    }
  end

  @doc "Consumes one typed stream chunk and returns newly visible canonical events."
  @spec consume(t(), Draught.Provider.OpenAI.Stream.Chunk.t()) ::
          {:ok, t(), [Draught.Event.nonterminal()]} | {:error, Draught.Error.Normalized.t()}
  def consume(%__MODULE__{status: :open} = state, {:choice, choice, usage}) do
    consume_choice(state, choice, usage)
  end

  def consume(%__MODULE__{status: :open}, {:usage, %Usage{}}) do
    Protocol.error("usage_before_finish", "Provider stream reported usage before finishing")
  end

  def consume(%__MODULE__{status: :finished}, {:choice, _choice, _usage}) do
    Protocol.error("data_after_finish", "Provider stream contained a choice after finishing")
  end

  def consume(%__MODULE__{status: :finished} = state, {:usage, %Usage{} = usage}) do
    with {:ok, updated} <- put_usage(state, usage) do
      {:ok, updated, []}
    end
  end

  @doc "Returns whether canonical output has crossed the external retry boundary."
  @spec output?(t()) :: boolean()
  def output?(%__MODULE__{output_emitted: output_emitted}) do
    output_emitted
  end

  defp consume_choice(state, choice, usage) do
    with {:ok, accumulated, delta_events} <- apply_delta(state, choice),
         {:ok, finished, finish_events} <- apply_finish(accumulated, choice.finish_reason),
         {:ok, updated} <- apply_choice_usage(finished, usage, choice.finish_reason) do
      events = delta_events ++ finish_events
      {:ok, mark_output(updated, events), events}
    end
  end

  defp apply_delta(%__MODULE__{} = state, choice) do
    delta = choice.delta

    with {:ok, output_bytes, output_fragments} <- retained_output(state, delta),
         {:ok, tool_calls} <- ToolCalls.append(state.tool_calls, delta.tool_calls),
         {:ok, events} <- Output.deltas(delta) do
      {:ok,
       %__MODULE__{
         state
         | text: prepend_fragment(state.text, delta.content),
           reasoning: prepend_fragment(state.reasoning, delta.reasoning),
           tool_calls: tool_calls,
           output_bytes: output_bytes,
           output_fragments: output_fragments
       }, events}
    end
  end

  defp apply_finish(%__MODULE__{} = state, nil) do
    {:ok, state, []}
  end

  defp apply_finish(%__MODULE__{} = state, :tool_calls) do
    with {:ok, calls} <- ToolCalls.finalize(state.tool_calls),
         :ok <- require_tool_calls(calls),
         {:ok, events} <- Output.tool_calls(calls) do
      {:ok, %__MODULE__{state | calls: calls, finish_reason: :tool_calls, status: :finished},
       events}
    end
  end

  defp apply_finish(%__MODULE__{} = state, reason) do
    has_tool_fragments = not ToolCalls.empty?(state.tool_calls)
    has_output = state.text != [] or state.reasoning != [] or reason == :content_filter
    finish_without_tools(has_tool_fragments, has_output, state, reason)
  end

  defp finish_without_tools(true, _has_output, _state, _reason) do
    invalid_finish()
  end

  defp finish_without_tools(false, false, _state, _reason) do
    invalid_finish()
  end

  defp finish_without_tools(false, true, %__MODULE__{} = state, reason) do
    {:ok, %__MODULE__{state | finish_reason: reason, status: :finished}, []}
  end

  defp require_tool_calls([_call | _rest]) do
    :ok
  end

  defp require_tool_calls([]) do
    invalid_finish()
  end

  defp apply_choice_usage(state, nil, _finish_reason) do
    {:ok, state}
  end

  defp apply_choice_usage(_state, %Usage{}, nil) do
    Protocol.error("usage_before_finish", "Provider stream reported usage before finishing")
  end

  defp apply_choice_usage(state, %Usage{} = usage, _finish_reason) do
    put_usage(state, usage)
  end

  defp put_usage(%__MODULE__{usage: nil} = state, usage) do
    {:ok, %__MODULE__{state | usage: usage}}
  end

  defp put_usage(%__MODULE__{}, _usage) do
    Protocol.error("duplicate_usage", "Provider stream reported usage more than once")
  end

  defp prepend_fragment(values, nil) do
    values
  end

  defp prepend_fragment(values, "") do
    values
  end

  defp prepend_fragment(values, value) do
    [value | values]
  end

  defp retained_output(state, delta) do
    bytes =
      state.output_bytes + fragment_bytes(delta.content) + fragment_bytes(delta.reasoning)

    fragments =
      state.output_fragments + fragment_count(delta.content) + fragment_count(delta.reasoning)

    retained_output_result(
      bytes <= state.max_output_bytes,
      fragments <= state.max_output_fragments,
      bytes,
      fragments
    )
  end

  defp retained_output_result(true, true, bytes, fragments) do
    {:ok, bytes, fragments}
  end

  defp retained_output_result(false, _fragments_valid, _bytes, _fragments) do
    Protocol.error(
      "stream_output_too_large",
      "Provider stream output exceeds the configured limit"
    )
  end

  defp retained_output_result(true, false, _bytes, _fragments) do
    Protocol.error(
      "too_many_stream_fragments",
      "Provider stream output exceeds the configured fragment limit"
    )
  end

  defp fragment_bytes(nil) do
    0
  end

  defp fragment_bytes(value) do
    byte_size(value)
  end

  defp fragment_count(value) when value in [nil, ""] do
    0
  end

  defp fragment_count(_value) do
    1
  end

  defp mark_output(%__MODULE__{} = state, []) do
    state
  end

  defp mark_output(%__MODULE__{} = state, [_event | _rest]) do
    %__MODULE__{state | output_emitted: true}
  end

  defp invalid_finish do
    Protocol.error("invalid_stream_finish", "Provider stream finish is inconsistent with output")
  end
end
