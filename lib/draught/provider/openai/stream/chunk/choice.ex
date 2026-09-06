defmodule Draught.Provider.OpenAI.Stream.Chunk.Choice do
  @moduledoc "Decodes choice zero and its optional stream finish reason."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.Chunk.Delta

  @finish_reasons %{
    "content_filter" => :content_filter,
    "length" => :length,
    "stop" => :stop,
    "tool_calls" => :tool_calls
  }

  @enforce_keys [:delta]
  defstruct [:delta, :finish_reason]

  @type t :: %__MODULE__{
          delta: Delta.t(),
          finish_reason: Draught.Provider.Response.finish_reason() | nil
        }

  @doc "Decodes a streamed provider choice."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(%{"index" => 0, "delta" => delta} = choice) do
    with {:ok, decoded_delta} <- Delta.decode(delta),
         {:ok, finish_reason} <- finish_reason(Map.get(choice, "finish_reason")) do
      {:ok, %__MODULE__{delta: decoded_delta, finish_reason: finish_reason}}
    end
  end

  def decode(_choice) do
    Protocol.error("invalid_stream_choice", "Provider stream choice is malformed")
  end

  defp finish_reason(nil) do
    {:ok, nil}
  end

  defp finish_reason(reason) when is_binary(reason) do
    {:ok, Map.get(@finish_reasons, reason, :other)}
  end

  defp finish_reason(_reason) do
    Protocol.error("invalid_stream_choice", "Provider stream finish reason is malformed")
  end
end
