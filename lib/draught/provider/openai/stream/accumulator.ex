defmodule Draught.Provider.OpenAI.Stream.Accumulator do
  @moduledoc "Accumulates OpenAI-compatible stream data into canonical events and a final response."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.Accumulator.Configuration
  alias Draught.Provider.OpenAI.Stream.Accumulator.Finalizer
  alias Draught.Provider.OpenAI.Stream.Accumulator.State
  alias Draught.Provider.OpenAI.Stream.Chunk

  @doc "Initializes bounded stream accumulation state."
  @spec new(map() | keyword()) :: {:ok, State.t()} | {:error, Draught.Error.Normalized.t()}
  def new(options \\ []) do
    with {:ok, configuration} <- Configuration.new(options) do
      {:ok, State.new(configuration)}
    end
  end

  @doc "Consumes one JSON data value returned by the SSE parser."
  @spec push(State.t(), term()) ::
          {:ok, State.t(), [Draught.Event.nonterminal()]}
          | {:error, Draught.Error.Normalized.t()}
  def push(%State{} = state, data) do
    with {:ok, chunk} <- Chunk.decode(data) do
      State.consume(state, chunk)
    end
  end

  @doc "Returns whether the stream has emitted canonical output."
  @spec output?(State.t()) :: boolean()
  def output?(%State{} = state) do
    State.output?(state)
  end

  @doc "Builds the final response after the provider has supplied a finish choice."
  @spec finish(State.t()) ::
          {:ok, Draught.Provider.Response.t()} | {:error, Draught.Error.Normalized.t()}
  def finish(%State{status: :finished} = state) do
    Finalizer.build(
      state.text,
      state.reasoning,
      state.calls,
      state.finish_reason,
      state.usage
    )
  end

  def finish(%State{status: :open}) do
    Protocol.error("incomplete_stream", "Provider stream ended before a finish choice")
  end
end
