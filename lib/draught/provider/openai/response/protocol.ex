defmodule Draught.Provider.OpenAI.Response.Protocol do
  @moduledoc """
  Constructs safe protocol failures for rejected compatible-provider payloads.
  """

  alias Draught.Error.Normalized
  alias Draught.Validation.Error

  @doc "Returns a non-retryable protocol error without retaining rejected input."
  @spec error(String.t(), String.t()) :: {:error, Normalized.t()}
  def error(code, message) do
    {:ok, normalized} =
      Normalized.new(:protocol, code, message, retryable: false)

    {:error, normalized}
  end

  @doc "Converts a canonical-constructor result into a safe protocol result."
  @spec canonical({:ok, value} | {:error, Error.t()}, String.t(), String.t()) ::
          {:ok, value} | {:error, Normalized.t()}
        when value: term()
  def canonical({:ok, value}, _code, _message) do
    {:ok, value}
  end

  def canonical({:error, %Error{}}, code, message) do
    error(code, message)
  end
end
