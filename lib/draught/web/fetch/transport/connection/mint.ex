defmodule Draught.Web.Fetch.Transport.Connection.Mint do
  @moduledoc """
  Opens one passive HTTP/1 connection to a validated address tuple.

  The logical hostname is used for Host, TLS SNI, and certificate verification,
  while the socket destination remains the validated address.
  """

  @behaviour Draught.Web.Fetch.Transport.Connection

  alias Draught.Web.Fetch.Transport.Limits
  alias Draught.Web.Target
  alias Mint.HTTP
  alias Mint.HTTP1

  @maximum_header_bytes 64 * 1024
  @socket_buffer_bytes 64 * 1024

  @impl Draught.Web.Fetch.Transport.Connection
  def request(%Target{} = target, address, %Limits{} = limits, _configuration) do
    deadline = now() + limits.timeout_ms
    options = connection_options(target, limits)

    case HTTP1.connect(target.scheme, address, target.port, options) do
      {:ok, connection} -> request_and_close(connection, target, limits, deadline)
      {:error, error} -> transport_error(error)
    end
  end

  defp connection_options(target, limits) do
    [
      hostname: target.host,
      max_header_list_size: @maximum_header_bytes,
      mode: :passive,
      transport_opts: transport_options(target.scheme, limits.timeout_ms)
    ]
  end

  defp transport_options(:http, timeout) do
    [recbuf: @socket_buffer_bytes, timeout: timeout]
  end

  defp transport_options(:https, timeout) do
    [cacerts: :public_key.cacerts_get(), recbuf: @socket_buffer_bytes, timeout: timeout]
  end

  defp request_and_close(connection, target, limits, deadline) do
    start_request(connection, target, limits, deadline)
  after
    HTTP.close(connection)
  end

  defp start_request(connection, target, limits, deadline) do
    headers = [
      {"accept", "text/plain, text/html, application/json, application/xml, text/xml"},
      {"accept-encoding", "identity"},
      {"user-agent", "draught-web/0.1"}
    ]

    deadline
    |> remaining()
    |> request_with_timeout(connection, target, limits, headers, deadline)
  end

  defp request_with_timeout(timeout, connection, target, limits, headers, deadline)
       when timeout > 0 do
    case HTTP.request(connection, "GET", target.request_target, headers, nil) do
      {:ok, updated, reference} -> receive_response(updated, reference, limits, deadline)
      {:error, _updated, error} -> transport_error(error)
    end
  end

  defp request_with_timeout(_timeout, _connection, _target, _limits, _headers, _deadline) do
    {:error, :timeout}
  end

  defp receive_response(connection, reference, limits, deadline) do
    state = %{body: [], bytes: 0, done: false, headers: [], status: nil}
    receive_next(connection, reference, limits.max_response_bytes, deadline, state)
  end

  defp receive_next(_connection, _reference, _maximum, _deadline, %{done: true} = state) do
    {:ok,
     %{
       body:
         state.body
         |> Enum.reverse()
         |> IO.iodata_to_binary(),
       headers: state.headers,
       status: state.status
     }}
  end

  defp receive_next(connection, reference, maximum, deadline, state) do
    timeout = remaining(deadline)
    receive_with_timeout(timeout, connection, reference, maximum, deadline, state)
  end

  defp receive_with_timeout(timeout, connection, reference, maximum, deadline, state)
       when timeout > 0 do
    receive_available(connection, reference, maximum, deadline, timeout, state)
  end

  defp receive_with_timeout(_timeout, _connection, _reference, _maximum, _deadline, _state) do
    {:error, :timeout}
  end

  defp receive_available(connection, reference, maximum, deadline, timeout, state) do
    case HTTP.recv(connection, 0, timeout) do
      {:ok, updated, events} ->
        with {:ok, next} <- apply_events(events, reference, maximum, state) do
          receive_next(updated, reference, maximum, deadline, next)
        end

      {:error, _updated, error, events} ->
        with {:ok, _next} <- apply_events(events, reference, maximum, state) do
          transport_error(error)
        end
    end
  end

  defp apply_events(events, reference, maximum, state) do
    Enum.reduce_while(events, {:ok, state}, fn event, {:ok, current} ->
      case apply_event(event, reference, maximum, current) do
        {:ok, next} -> {:cont, {:ok, next}}
        {:error, _reason} = result -> {:halt, result}
      end
    end)
  end

  defp apply_event({:status, reference, status}, reference, _maximum, state)
       when is_integer(status) and is_nil(state.status) do
    {:ok, %{state | status: status}}
  end

  defp apply_event({:headers, reference, headers}, reference, maximum, state)
       when is_list(headers) and state.headers == [] do
    with :ok <- declared_length(headers, maximum) do
      {:ok, %{state | headers: headers}}
    end
  end

  defp apply_event({:data, reference, data}, reference, maximum, state) when is_binary(data) do
    size = state.bytes + byte_size(data)
    body_event(size, data, maximum, state)
  end

  defp apply_event({:done, reference}, reference, _maximum, state)
       when is_integer(state.status) do
    {:ok, %{state | done: true}}
  end

  defp apply_event({:error, reference, _reason}, reference, _maximum, _state) do
    {:error, :request_failed}
  end

  defp apply_event(_event, _reference, _maximum, _state) do
    {:error, :request_failed}
  end

  defp body_event(size, data, maximum, state) when size <= maximum do
    {:ok, %{state | body: [data | state.body], bytes: size}}
  end

  defp body_event(_size, _data, _maximum, _state) do
    {:error, :too_large}
  end

  defp declared_length(headers, maximum) do
    values = for {"content-length", value} <- headers, do: value

    case values do
      [] -> :ok
      [value] -> parse_length(value, maximum)
      _values -> {:error, :request_failed}
    end
  end

  defp parse_length(value, maximum) do
    case Integer.parse(value) do
      {length, ""} when length >= 0 and length <= maximum -> :ok
      {length, ""} when length > maximum -> {:error, :too_large}
      _result -> {:error, :request_failed}
    end
  end

  defp transport_error(%Mint.TransportError{reason: :timeout}) do
    {:error, :timeout}
  end

  defp transport_error(_error) do
    {:error, :request_failed}
  end

  defp now do
    System.monotonic_time(:millisecond)
  end

  defp remaining(deadline) do
    max(deadline - now(), 0)
  end
end
