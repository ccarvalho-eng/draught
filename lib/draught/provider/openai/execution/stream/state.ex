defmodule Draught.Provider.OpenAI.Execution.Stream.State do
  @moduledoc """
  Holds the SSE parser and canonical accumulator for one transport attempt.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Configuration.Limits
  alias Draught.Provider.OpenAI.Stream.Accumulator
  alias Draught.Provider.OpenAI.Stream.Accumulator.State
  alias Draught.Provider.OpenAI.Stream.SSE

  @enforce_keys [:sse, :accumulator]
  defstruct [:sse, :accumulator, :error]

  @type t :: %__MODULE__{
          sse: SSE.t(),
          accumulator: State.t(),
          error: Normalized.t() | nil
        }

  @doc "Initializes one attempt from validated provider limits."
  @spec new(Limits.t()) :: {:ok, t()} | {:error, Normalized.t()}
  def new(%Limits{} = limits) do
    accumulator_options = [
      max_output_bytes: limits.max_output_bytes,
      max_output_fragments: limits.max_output_fragments,
      max_calls: limits.max_calls,
      max_arguments_bytes: limits.max_arguments_bytes
    ]

    with {:ok, sse} <- SSE.new(max_event_bytes: limits.max_event_bytes),
         {:ok, accumulator} <- Accumulator.new(accumulator_options) do
      {:ok, %__MODULE__{sse: sse, accumulator: accumulator}}
    end
  end

  @doc "Returns whether this attempt has emitted canonical output."
  @spec output?(t()) :: boolean()
  def output?(%__MODULE__{accumulator: accumulator}) do
    Accumulator.output?(accumulator)
  end
end
