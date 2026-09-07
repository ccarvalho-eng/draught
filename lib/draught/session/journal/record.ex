defmodule Draught.Session.Journal.Record do
  @moduledoc false

  alias Draught.Session.Journal.Codec.Event
  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Record.Decoder
  alias Draught.Session.Journal.Retention

  @schema_version 1
  @enforce_keys [:event, :recorded_at, :sequence]
  defstruct [:event, :recorded_at, :sequence]

  @type t :: %__MODULE__{
          event: Draught.Session.Journal.Event.t(),
          recorded_at: DateTime.t(),
          sequence: pos_integer()
        }

  @doc "Returns the current journal record schema version."
  @spec schema_version() :: pos_integer()
  def schema_version do
    @schema_version
  end

  @doc "Builds a record from canonical values."
  @spec new(pos_integer(), DateTime.t(), Draught.Session.Journal.Event.t()) :: t()
  def new(sequence, %DateTime{} = recorded_at, event)
      when is_integer(sequence) and sequence > 0 do
    %__MODULE__{event: event, recorded_at: recorded_at, sequence: sequence}
  end

  @doc "Encodes one record as a single JSON line without its trailing newline."
  @spec encode(t(), Retention.t()) :: {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(%__MODULE__{} = record, %Retention{} = retention) do
    {type, data} = Event.encode(record.event, retention)

    %{
      "data" => data,
      "recorded_at" => DateTime.to_iso8601(record.recorded_at),
      "schema_version" => @schema_version,
      "sequence" => record.sequence,
      "type" => type
    }
    |> Jason.encode()
    |> encode_result()
  end

  @doc "Decodes and validates one complete JSON journal line."
  @spec decode(binary()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(line) do
    Decoder.decode(line, @schema_version)
  end

  defp encode_result({:ok, encoded}) do
    {:ok, encoded}
  end

  defp encode_result({:error, _error}) do
    {:error, Failure.corrupt()}
  end
end
