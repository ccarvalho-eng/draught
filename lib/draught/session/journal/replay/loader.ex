defmodule Draught.Session.Journal.Replay.Loader do
  @moduledoc false

  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Record
  alias Draught.Session.Journal.Replay
  alias Draught.Session.Journal.Replay.Reducer

  @maximum_journal_bytes 67_108_864
  @maximum_record_bytes 4_194_304

  @doc "Loads and reduces one complete append-only journal."
  @spec load(String.t(), String.t()) ::
          {:ok, Replay.t()} | {:error, Draught.Error.Normalized.t()}
  def load(path, id) do
    case File.read(path) do
      {:ok, binary} -> decode(binary, id)
      {:error, :enoent} -> {:ok, Replay.empty(id)}
      {:error, _reason} -> {:error, Failure.io()}
    end
  end

  @doc "Decodes journal bytes for deterministic tests and local replay."
  @spec decode(binary(), String.t()) ::
          {:ok, Replay.t()} | {:error, Draught.Error.Normalized.t()}
  def decode(binary, id) when byte_size(binary) <= @maximum_journal_bytes do
    with {:ok, lines} <- lines(binary),
         {:ok, replay} <- reduce(lines, Replay.empty(id)) do
      {:ok, Reducer.finalize(replay)}
    end
  end

  def decode(_binary, _id) do
    {:error, Failure.corrupt()}
  end

  defp lines("") do
    {:ok, []}
  end

  defp lines(binary) do
    binary
    |> String.ends_with?("\n")
    |> framed_lines(binary)
  end

  defp framed_lines(true, binary) do
    lines =
      binary
      |> String.split("\n", trim: false)
      |> Enum.drop(-1)

    lines
    |> Enum.all?(&(&1 != ""))
    |> nonempty_lines(lines)
  end

  defp framed_lines(false, _binary) do
    {:error, Failure.corrupt()}
  end

  defp nonempty_lines(true, lines) do
    {:ok, lines}
  end

  defp nonempty_lines(false, _lines) do
    {:error, Failure.corrupt()}
  end

  defp reduce(lines, replay) do
    Enum.reduce_while(lines, {:ok, replay}, fn line, {:ok, current} ->
      with :ok <- record_size(line),
           {:ok, record} <- Record.decode(line),
           {:ok, updated} <- Reducer.apply(current, record) do
        {:cont, {:ok, updated}}
      else
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp record_size(line) when byte_size(line) <= @maximum_record_bytes do
    :ok
  end

  defp record_size(_line) do
    {:error, Failure.corrupt()}
  end
end
