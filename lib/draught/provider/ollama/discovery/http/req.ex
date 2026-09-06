defmodule Draught.Provider.Ollama.Discovery.HTTP.Req do
  @moduledoc """
  Executes bounded Ollama discovery requests through Req.
  """

  @behaviour Draught.Provider.Ollama.Discovery.HTTP

  alias Draught.Provider.Ollama.Discovery.Configuration
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Response
  alias Draught.Transport.Response.Body

  @body_key :draught_ollama_discovery_body

  @impl Draught.Provider.Ollama.Discovery.HTTP
  @spec request(
          Draught.Provider.Ollama.Discovery.HTTP.method(),
          String.t(),
          Draught.Provider.Ollama.Discovery.HTTP.body(),
          Configuration.t()
        ) :: {:ok, Response.t()} | {:error, Failure.t()}
  def request(method, url, request_body, %Configuration{} = configuration) do
    body = Body.new(configuration.max_response_bytes)

    method
    |> options(url, request_body, configuration, body)
    |> Req.request()
    |> result(body)
  end

  defp options(method, url, request_body, configuration, body) do
    base = [
      method: method,
      url: url,
      into: into(body),
      retry: false,
      redirect: false,
      decode_body: false,
      connect_options: [timeout: configuration.connect_timeout_ms],
      receive_timeout: configuration.receive_timeout_ms,
      request_timeout: configuration.request_timeout_ms
    ]

    request_options(request_body, base)
  end

  defp request_options(nil, options) do
    options
  end

  defp request_options(body, options) do
    Keyword.put(options, :json, body)
  end

  defp into(initial) do
    fn {:data, data}, {request, response} ->
      retain(request, response, initial, data)
    end
  end

  defp retain(request, response, initial, data) do
    response.status
    |> successful?()
    |> retain_result(request, response, initial, data)
  end

  defp retain_result(true, request, response, initial, data) do
    body = Req.Response.get_private(response, @body_key, initial)
    {action, updated} = Body.push(body, data)
    response = Req.Response.put_private(response, @body_key, updated)
    {action, {request, response}}
  end

  defp retain_result(false, request, response, _initial, _data) do
    {:cont, {request, response}}
  end

  defp result({:ok, response}, initial) do
    response.status
    |> successful?()
    |> response_result(response, initial)
  end

  defp result({:error, exception}, _initial) do
    {:error, failure(exception)}
  end

  defp response_result(true, response, initial) do
    response
    |> Req.Response.get_private(@body_key, initial)
    |> Body.finish()
    |> success(response.status)
  end

  defp response_result(false, response, _initial) do
    {:ok, %Response{status: response.status, body: nil}}
  end

  defp success({:ok, body}, status) do
    {:ok, %Response{status: status, body: body}}
  end

  defp success({:error, :too_large}, _status) do
    {:error, Failure.new(:response_too_large)}
  end

  defp failure(%Req.TransportError{reason: :timeout}) do
    Failure.new(:timeout)
  end

  defp failure(%Req.TransportError{reason: reason})
       when reason in [:econnrefused, :closed, :nxdomain] do
    Failure.new(:unavailable)
  end

  defp failure(_exception) do
    Failure.new(:unknown)
  end

  defp successful?(status) do
    status >= 200 and status <= 299
  end
end
