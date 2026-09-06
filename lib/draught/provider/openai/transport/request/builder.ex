defmodule Draught.Provider.OpenAI.Transport.Request.Builder do
  @moduledoc """
  Builds a transport request from canonical provider values and configuration.
  """

  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Configuration.Credential
  alias Draught.Provider.OpenAI.Request.Encoder
  alias Draught.Provider.OpenAI.Transport.Request

  @doc "Builds a complete or streamed chat-completions HTTP request."
  @spec build(Draught.Provider.Request.t(), Configuration.t(), Encoder.mode()) ::
          {:ok, Request.t()} | {:error, Draught.Error.Normalized.t()}
  def build(request, %Configuration{} = configuration, mode) do
    with {:ok, body} <- Encoder.encode(request, configuration, mode) do
      {:ok,
       %Request{
         url: configuration.base_url <> "/chat/completions",
         headers: headers(configuration),
         body: body,
         connect_timeout_ms: configuration.timeouts.connect_ms,
         receive_timeout_ms: configuration.timeouts.receive_ms,
         request_timeout_ms: configuration.timeouts.request_ms,
         max_response_bytes: configuration.limits.max_response_bytes
       }}
    end
  end

  defp headers(%Configuration{credential: nil, headers: headers}) do
    headers
  end

  defp headers(%Configuration{credential: credential, headers: headers}) do
    authorization = "Bearer " <> Credential.value(credential)
    Map.put(headers, "authorization", authorization)
  end
end
