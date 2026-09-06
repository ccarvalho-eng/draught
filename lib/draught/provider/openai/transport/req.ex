defmodule Draught.Provider.OpenAI.Transport.Req do
  @moduledoc """
  Executes OpenAI HTTP requests through Req with provider-owned safety settings.
  """

  @behaviour Draught.Provider.OpenAI.Transport

  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.OpenAI.Transport.Req.Body
  alias Draught.Provider.OpenAI.Transport.Request
  alias Draught.Provider.OpenAI.Transport.Response

  @complete_body_key :draught_openai_complete_body
  @stream_state_key :draught_openai_stream_state

  @type client :: (keyword() -> {:ok, Req.Response.t()} | {:error, Exception.t()})

  @impl Draught.Provider.OpenAI.Transport
  @spec complete(Request.t(), client() | nil) ::
          {:ok, Response.t()} | {:error, Failure.t()}
  def complete(%Request{} = request, client \\ nil) do
    body = Body.new(request.max_response_bytes)
    options = options(request, complete_into(body))

    client
    |> run(options)
    |> complete_result(body)
  end

  @impl Draught.Provider.OpenAI.Transport
  @spec stream(
          Request.t(),
          client() | nil,
          state,
          Draught.Provider.OpenAI.Transport.stream_reducer(state)
        ) ::
          {:ok, Response.t(), state} | {:error, Failure.t(), boolean()}
        when state: term()
  def stream(%Request{} = request, client, initial, reducer) do
    marker = :atomics.new(1, signed: false)
    options = options(request, stream_into(initial, reducer, marker))

    client
    |> run(options)
    |> stream_result(initial, marker)
  end

  defp options(request, into) do
    [
      method: :post,
      url: request.url,
      headers: request.headers,
      json: request.body,
      into: into,
      retry: false,
      redirect: false,
      decode_body: false,
      connect_options: [timeout: request.connect_timeout_ms],
      receive_timeout: request.receive_timeout_ms,
      request_timeout: request.request_timeout_ms
    ]
  end

  defp complete_into(initial) do
    fn {:data, data}, {request, response} ->
      complete_chunk(request, response, initial, data)
    end
  end

  defp complete_chunk(request, response, initial, data) do
    response.status
    |> successful?()
    |> complete_chunk_result(request, response, initial, data)
  end

  defp complete_chunk_result(true, request, response, initial, data) do
    retain_complete_chunk(request, response, initial, data)
  end

  defp complete_chunk_result(false, request, response, _initial, _data) do
    {:cont, {request, response}}
  end

  defp retain_complete_chunk(request, response, initial, data) do
    body = Req.Response.get_private(response, @complete_body_key, initial)
    {action, updated} = Body.push(body, data)
    response = Req.Response.put_private(response, @complete_body_key, updated)
    {action, {request, response}}
  end

  defp stream_into(initial, reducer, marker) do
    fn {:data, data}, {request, response} ->
      stream_chunk(request, response, initial, reducer, marker, data)
    end
  end

  defp stream_chunk(request, response, initial, reducer, marker, data) do
    response.status
    |> successful?()
    |> stream_chunk_result(request, response, initial, reducer, marker, data)
  end

  defp stream_chunk_result(true, request, response, initial, reducer, marker, data) do
    reduce_stream_chunk(request, response, initial, reducer, marker, data)
  end

  defp stream_chunk_result(false, request, response, _initial, _reducer, _marker, _data) do
    {:cont, {request, response}}
  end

  defp reduce_stream_chunk(request, response, initial, reducer, marker, data) do
    state = Req.Response.get_private(response, @stream_state_key, initial)
    {action, updated, output_emitted} = reducer.(data, state)
    mark_output(marker, output_emitted)
    response = Req.Response.put_private(response, @stream_state_key, updated)
    {action, {request, response}}
  end

  defp complete_result({:ok, response}, initial) do
    response.status
    |> successful?()
    |> complete_response(response, initial)
  end

  defp complete_result({:error, exception}, _initial) do
    {:error, failure(exception)}
  end

  defp complete_response(true, response, initial) do
    complete_success(response, initial)
  end

  defp complete_response(false, response, _initial) do
    {:ok, transport_response(response.status, nil)}
  end

  defp complete_success(response, initial) do
    response
    |> Req.Response.get_private(@complete_body_key, initial)
    |> Body.finish()
    |> complete_body_result(response.status)
  end

  defp complete_body_result({:ok, body}, status) do
    {:ok, transport_response(status, body)}
  end

  defp complete_body_result({:error, %Failure{}} = result, _status) do
    result
  end

  defp stream_result({:ok, response}, initial, _marker) do
    state = Req.Response.get_private(response, @stream_state_key, initial)
    {:ok, transport_response(response.status, nil), state}
  end

  defp stream_result({:error, exception}, _initial, marker) do
    {:error, failure(exception), output_marked?(marker)}
  end

  defp run(nil, options) do
    Req.request(options)
  end

  defp run(client, options) when is_function(client, 1) do
    client.(options)
  end

  defp mark_output(marker, true) do
    :atomics.put(marker, 1, 1)
  end

  defp mark_output(_marker, false) do
    :ok
  end

  defp output_marked?(marker) do
    :atomics.get(marker, 1) == 1
  end

  defp successful?(status) do
    status >= 200 and status <= 299
  end

  defp transport_response(status, body) do
    %Response{status: status, body: body}
  end

  defp failure(%Req.TransportError{reason: :timeout}) do
    Failure.new(:timeout)
  end

  defp failure(%Req.TransportError{reason: :econnrefused}) do
    Failure.new(:connection_refused)
  end

  defp failure(%Req.TransportError{reason: :closed}) do
    Failure.new(:closed)
  end

  defp failure(%Req.HTTPError{protocol: :http2, reason: :unprocessed}) do
    Failure.new(:unprocessed)
  end

  defp failure(_exception) do
    Failure.new(:unknown)
  end
end
