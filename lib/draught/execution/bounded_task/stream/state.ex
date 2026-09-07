defmodule Draught.Execution.BoundedTask.Stream.State do
  @moduledoc """
  Holds one immutable bounded provider-stream relay operation.
  """

  alias Draught.Error.Normalized

  @enforce_keys [
    :crash_error,
    :deadline,
    :maximum_bytes,
    :output_error,
    :relay,
    :sink,
    :task,
    :timeout_error
  ]
  defstruct [
    :crash_error,
    :deadline,
    :maximum_bytes,
    :output_error,
    :relay,
    :sink,
    :task,
    :timeout_error,
    consumed_bytes: 0
  ]

  @type t :: %__MODULE__{
          consumed_bytes: non_neg_integer(),
          crash_error: Normalized.t(),
          deadline: integer(),
          maximum_bytes: pos_integer(),
          output_error: Normalized.t(),
          relay: reference(),
          sink: (term() -> term()),
          task: Task.t(),
          timeout_error: Normalized.t()
        }

  @doc "Builds the initial relay state from an owned task and fixed limits."
  @spec new(Task.t(), reference(), (term() -> term()), pos_integer(), integer(), keyword()) :: t()
  def new(task, relay, sink, maximum_bytes, deadline, errors) do
    %__MODULE__{
      crash_error: Keyword.fetch!(errors, :crash),
      deadline: deadline,
      maximum_bytes: maximum_bytes,
      output_error: Keyword.fetch!(errors, :output),
      relay: relay,
      sink: sink,
      task: task,
      timeout_error: Keyword.fetch!(errors, :timeout)
    }
  end

  @doc "Records the cumulative encoded event size after a successful relay."
  @spec consume(t(), non_neg_integer()) :: t()
  def consume(%__MODULE__{} = state, bytes) when is_integer(bytes) and bytes >= 0 do
    %{state | consumed_bytes: bytes}
  end
end
