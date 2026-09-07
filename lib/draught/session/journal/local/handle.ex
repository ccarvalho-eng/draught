defmodule Draught.Session.Journal.Local.Handle do
  @moduledoc false

  alias Draught.Session.Journal.Local.Configuration

  @enforce_keys [:configuration, :next_sequence]
  defstruct [:configuration, :next_sequence]

  @type t :: %__MODULE__{
          configuration: Configuration.t(),
          next_sequence: pos_integer()
        }

  @doc "Builds a local writer handle at the next replayed sequence."
  @spec new(Configuration.t(), pos_integer()) :: t()
  def new(%Configuration{} = configuration, next_sequence) do
    %__MODULE__{configuration: configuration, next_sequence: next_sequence}
  end

  @doc "Advances a writer handle after one durable append."
  @spec advance(t()) :: t()
  def advance(%__MODULE__{} = handle) do
    %{handle | next_sequence: handle.next_sequence + 1}
  end
end
