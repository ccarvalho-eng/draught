defmodule Draught.Session.Journal.Record.Decoder do
  @moduledoc false

  alias Draught.Session.Journal.Codec.Event
  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Record

  @expected_keys ["data", "recorded_at", "schema_version", "sequence", "type"]

  @doc "Decodes one record under the supplied current schema version."
  @spec decode(term(), pos_integer()) ::
          {:ok, Record.t()} | {:error, Draught.Error.Normalized.t()}
  def decode(line, current_version) when is_binary(line) do
    with {:ok, data} <- Jason.decode(line),
         :ok <- envelope(data, current_version) do
      fields(data)
    else
      {:error, %Draught.Error.Normalized{}} = result -> result
      _result -> corrupt()
    end
  end

  def decode(_line, _current_version) do
    corrupt()
  end

  defp envelope(data, current_version) do
    with :ok <- keys(data) do
      version(Map.get(data, "schema_version"), current_version)
    end
  end

  defp fields(data) do
    with {:ok, sequence} <-
           data
           |> Map.get("sequence")
           |> sequence(),
         {:ok, recorded_at} <-
           data
           |> Map.get("recorded_at")
           |> timestamp(),
         {:ok, event} <- decode_event(data) do
      {:ok, Record.new(sequence, recorded_at, event)}
    else
      _result -> corrupt()
    end
  end

  defp decode_event(data) do
    type = Map.get(data, "type")
    event_data = Map.get(data, "data")
    Event.decode(type, event_data)
  end

  defp keys(data) when is_map(data) do
    data
    |> Map.keys()
    |> Enum.sort()
    |> keys_result()
  end

  defp keys(_data) do
    corrupt()
  end

  defp keys_result(@expected_keys) do
    :ok
  end

  defp keys_result(_keys) do
    corrupt()
  end

  defp version(current, current) do
    :ok
  end

  defp version(version, current) when is_integer(version) and version > current do
    {:error, Failure.unsupported_version()}
  end

  defp version(_version, _current) do
    corrupt()
  end

  defp sequence(value) when is_integer(value) and value > 0 do
    {:ok, value}
  end

  defp sequence(_value) do
    corrupt()
  end

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, 0} -> {:ok, timestamp}
      _result -> corrupt()
    end
  end

  defp timestamp(_value) do
    corrupt()
  end

  defp corrupt do
    {:error, Failure.corrupt()}
  end
end
