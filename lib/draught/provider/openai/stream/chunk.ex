defmodule Draught.Provider.OpenAI.Stream.Chunk do
  @moduledoc "Decodes one OpenAI-compatible stream data value into a typed chunk."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Response.Usage
  alias Draught.Provider.OpenAI.Stream.Chunk.Choice

  @type t ::
          {:choice, Choice.t(), Draught.Provider.Usage.t() | nil}
          | {:usage, Draught.Provider.Usage.t()}

  @doc "Decodes a JSON data value from the SSE parser."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(data) when is_binary(data) do
    with {:ok, payload} <- decode_json(data) do
      decode_payload(payload)
    end
  end

  def decode(_data) do
    invalid_chunk()
  end

  defp decode_json(data) do
    case Jason.decode(data) do
      {:ok, %{} = payload} -> {:ok, payload}
      {:ok, _payload} -> invalid_chunk()
      {:error, _reason} -> invalid_chunk()
    end
  end

  defp decode_payload(%{"choices" => [choice]} = payload) do
    raw_usage = Map.get(payload, "usage")

    with {:ok, decoded_choice} <- Choice.decode(choice),
         {:ok, usage} <- Usage.decode(raw_usage) do
      {:ok, {:choice, decoded_choice, usage}}
    end
  end

  defp decode_payload(%{"choices" => [], "usage" => usage}) do
    decode_usage_payload(usage)
  end

  defp decode_payload(_payload) do
    invalid_chunk()
  end

  defp decode_usage_payload(nil) do
    invalid_chunk()
  end

  defp decode_usage_payload(usage) do
    with {:ok, %Draught.Provider.Usage{} = decoded} <- Usage.decode(usage) do
      {:ok, {:usage, decoded}}
    end
  end

  defp invalid_chunk do
    Protocol.error("invalid_stream_chunk", "Provider stream data is malformed")
  end
end
