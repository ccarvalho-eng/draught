defmodule Draught.Provider.OpenAI.Response.Decoder do
  @moduledoc """
  Decodes complete OpenAI-compatible chat completion payloads.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Response.Choice
  alias Draught.Provider.OpenAI.Response.Usage
  alias Draught.Provider.Response

  @doc "Decodes one complete response into canonical provider values."
  @spec decode(term()) :: {:ok, Response.t()} | {:error, Normalized.t()}
  def decode(%{"choices" => [choice]} = payload) do
    with {:ok, {message, finish_reason}} <- Choice.decode(choice),
         {:ok, usage} <- usage(payload) do
      %{message: message, finish_reason: finish_reason, usage: usage}
      |> Response.new()
      |> Protocol.canonical("invalid_response", "provider response is internally inconsistent")
    end
  end

  def decode(_payload) do
    Protocol.error(
      "invalid_response_body",
      "provider response must contain exactly one choice"
    )
  end

  defp usage(payload) do
    payload
    |> Map.get("usage")
    |> Usage.decode()
  end
end
