defmodule Draught.CLI.Task.Stream.Projector.State do
  @moduledoc """
  Holds immutable sequencing and visible-output state for one CLI task stream.
  """

  @enforce_keys [:format, :maximum_bytes]
  defstruct current_iteration: nil,
            assistant_open: false,
            current_text: "",
            emitted_bytes: 0,
            format: nil,
            last_iteration: nil,
            line_open: false,
            maximum_bytes: nil,
            presentation: :plain,
            sequence: 1,
            status: :open,
            styled: false

  @type t :: %__MODULE__{
          current_iteration: pos_integer() | nil,
          assistant_open: boolean(),
          current_text: String.t(),
          emitted_bytes: non_neg_integer(),
          format: :jsonl | :text,
          last_iteration: pos_integer() | nil,
          line_open: boolean(),
          maximum_bytes: pos_integer(),
          presentation: :interactive | :plain,
          sequence: pos_integer(),
          status: :open | :terminal,
          styled: boolean()
        }

  @doc "Builds the initial state for one bounded output projection."
  @spec new(:jsonl | :text, pos_integer(), keyword()) :: t()
  def new(format, maximum_bytes, options \\ [])
      when format in [:jsonl, :text] and is_integer(maximum_bytes) and maximum_bytes > 0 do
    %__MODULE__{
      format: format,
      maximum_bytes: maximum_bytes,
      presentation: Keyword.get(options, :presentation, :plain),
      styled: Keyword.get(options, :styled, false)
    }
  end

  @doc "Records bytes successfully written for nonterminal events."
  @spec record_bytes(t(), non_neg_integer()) :: t()
  def record_bytes(%__MODULE__{} = state, bytes) when is_integer(bytes) and bytes >= 0 do
    %{state | emitted_bytes: state.emitted_bytes + bytes}
  end

  @doc "Records one visible text delta and advances sequence state."
  @spec record_text(t(), pos_integer(), String.t()) :: t()
  def record_text(%__MODULE__{} = state, iteration, content) do
    current_text = append_text(state, iteration, content)

    %{
      state
      | current_iteration: iteration,
        assistant_open: true,
        current_text: current_text,
        line_open: not String.ends_with?(content, "\n"),
        sequence: state.sequence + 1
    }
  end

  @doc "Advances the event sequence and records the current line state."
  @spec advance(t(), boolean()) :: t()
  def advance(%__MODULE__{} = state, line_open) do
    %{state | assistant_open: false, line_open: line_open, sequence: state.sequence + 1}
  end

  @doc "Records the iteration represented by the retained provider result."
  @spec retain_iteration(t(), pos_integer()) :: t()
  def retain_iteration(%__MODULE__{} = state, iteration) do
    %{state | last_iteration: iteration}
  end

  @doc "Returns whether visible text was emitted for the retained final iteration."
  @spec streamed_final_iteration?(t()) :: boolean()
  def streamed_final_iteration?(%__MODULE__{} = state) do
    state.current_iteration == state.last_iteration and state.current_text != ""
  end

  @doc "Closes the projector after its terminal sequence value is consumed."
  @spec terminal(t()) :: t()
  def terminal(%__MODULE__{} = state) do
    %{state | line_open: false, sequence: state.sequence + 1, status: :terminal}
  end

  defp append_text(
         %__MODULE__{current_iteration: iteration, current_text: text},
         iteration,
         content
       ) do
    text <> content
  end

  defp append_text(%__MODULE__{}, _iteration, content) do
    content
  end
end
