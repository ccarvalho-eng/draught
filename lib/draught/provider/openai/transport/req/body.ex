defmodule Draught.Provider.OpenAI.Transport.Req.Body do
  @moduledoc """
  Retains a complete response body within a fixed byte limit.
  """

  alias Draught.Provider.OpenAI.Transport.Failure

  @enforce_keys [:chunks, :bytes, :maximum_bytes]
  defstruct [:chunks, :bytes, :maximum_bytes, :failure]

  @type t :: %__MODULE__{
          chunks: [binary()],
          bytes: non_neg_integer(),
          maximum_bytes: pos_integer(),
          failure: Failure.t() | nil
        }

  @doc "Initializes empty bounded body retention."
  @spec new(pos_integer()) :: t()
  def new(maximum_bytes) do
    %__MODULE__{chunks: [], bytes: 0, maximum_bytes: maximum_bytes}
  end

  @doc "Appends one body chunk or halts after clearing oversized content."
  @spec push(t(), binary()) :: {:cont | :halt, t()}
  def push(%__MODULE__{} = body, chunk) do
    bytes = body.bytes + byte_size(chunk)
    push_result(bytes <= body.maximum_bytes, body, chunk, bytes)
  end

  @doc "Returns the assembled body or its sanitized retention failure."
  @spec finish(t()) :: {:ok, binary()} | {:error, Failure.t()}
  def finish(%__MODULE__{failure: %Failure{} = failure}) do
    {:error, failure}
  end

  def finish(%__MODULE__{chunks: chunks}) do
    body =
      chunks
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {:ok, body}
  end

  defp push_result(true, %__MODULE__{} = body, chunk, bytes) do
    {:cont, %__MODULE__{body | chunks: [chunk | body.chunks], bytes: bytes}}
  end

  defp push_result(false, %__MODULE__{} = body, _chunk, _bytes) do
    failure = Failure.new(:response_too_large)
    {:halt, %__MODULE__{body | chunks: [], bytes: 0, failure: failure}}
  end
end
