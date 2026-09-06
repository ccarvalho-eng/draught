defmodule Draught.Provider.OpenAI.Execution.Completion.Result do
  @moduledoc false

  alias Draught.Provider.OpenAI.Failure.Normalizer
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Response.Decoder
  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.OpenAI.Transport.Response

  @doc "Normalizes one complete transport result for the retry boundary."
  @spec normalize(term()) :: Draught.Provider.OpenAI.Execution.Retry.attempt_result(term())
  def normalize({:ok, %Response{status: status, body: body}})
      when status >= 200 and status <= 299 do
    body
    |> decode_body()
    |> decoded_result()
  end

  def normalize({:ok, %Response{status: status}}) when is_integer(status) do
    {:error, Normalizer.http(status), false}
  end

  def normalize({:error, %Failure{} = failure}) do
    {:error, Normalizer.transport(failure), false}
  end

  def normalize(_result) do
    protocol_attempt("invalid_transport_result", "OpenAI transport returned an invalid result")
  end

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, payload} ->
        Decoder.decode(payload)

      {:error, _reason} ->
        Protocol.error("invalid_response", "Provider response is not valid JSON")
    end
  end

  defp decode_body(_body) do
    Protocol.error("invalid_response", "Provider response body is missing")
  end

  defp decoded_result({:ok, response}) do
    {:ok, response}
  end

  defp decoded_result({:error, error}) do
    {:error, error, false}
  end

  defp protocol_attempt(code, message) do
    {:error, error} = Protocol.error(code, message)
    {:error, error, false}
  end
end
