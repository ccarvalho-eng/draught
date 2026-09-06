defmodule Draught.Provider.OpenAI.Stream.SSE.Frame do
  @moduledoc """
  Extracts the data value from one bounded SSE frame.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Protocol

  @type value :: :ignore | :done | {:data, binary()}

  @doc "Decodes one complete frame without retaining non-data fields."
  @spec decode(binary(), pos_integer()) :: {:ok, value()} | {:error, Normalized.t()}
  def decode(frame, maximum_bytes) when byte_size(frame) <= maximum_bytes do
    values =
      frame
      |> :binary.split("\n", [:global])
      |> Enum.reduce([], &collect_data/2)
      |> Enum.reverse()

    frame_value(values)
  end

  def decode(_frame, _maximum_bytes) do
    Protocol.error("event_too_large", "provider stream event exceeds the byte limit")
  end

  defp collect_data("data:" <> value, values) do
    [strip_optional_space(value) | values]
  end

  defp collect_data(_line, values) do
    values
  end

  defp strip_optional_space(" " <> value) do
    value
  end

  defp strip_optional_space(value) do
    value
  end

  defp frame_value([]) do
    {:ok, :ignore}
  end

  defp frame_value(values) do
    data = Enum.join(values, "\n")
    done_value(data)
  end

  defp done_value("[DONE]") do
    {:ok, :done}
  end

  defp done_value(data) do
    {:ok, {:data, data}}
  end
end
