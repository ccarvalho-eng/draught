defmodule Draught.Web.Fetch.Transport.Connection.MintTest do
  use ExUnit.Case, async: true

  alias Draught.Web.Fetch.Transport.Connection.Mint
  alias Draught.Web.Fetch.Transport.Limits
  alias Draught.Web.Target

  setup do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, packet: :raw, reuseaddr: true])

    {:ok, {_address, port}} = :inet.sockname(listener)

    on_exit(fn ->
      :gen_tcp.close(listener)
    end)

    %{listener: listener, port: port}
  end

  test "pins the socket address while preserving the logical host and fixed headers", context do
    owner = self()
    server = serve(context.listener, owner, &send_page/1)
    target = target(context.port)

    assert {:ok, response} = Mint.request(target, {127, 0, 0, 1}, limits(), nil)
    assert response.status == 200
    assert response.body == "page"

    assert_receive {:request, request}
    assert request =~ "get /path?query=visible http/1.1\r\n"
    assert request =~ "host: example.com:#{context.port}\r\n"
    assert request =~ "accept-encoding: identity\r\n"
    assert request =~ "user-agent: draught-web/0.1\r\n"
    refute request =~ "authorization:"
    refute request =~ "cookie:"
    refute request =~ "proxy-authorization:"
    assert Task.await(server) == :ok
  end

  test "rejects streamed response bytes beyond the configured maximum", context do
    owner = self()

    server =
      serve(context.listener, owner, fn socket ->
        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\nconnection: close\r\n\r\n"
          )

        result = :gen_tcp.send(socket, String.duplicate("x", 64))
        assert result in [:ok, {:error, :closed}]
      end)

    target = target(context.port)

    assert {:error, :too_large} =
             Mint.request(target, {127, 0, 0, 1}, limits(16), nil)

    assert_receive {:request, _request}
    assert Task.await(server) == :ok
  end

  test "rejects malformed or duplicate declared lengths", context do
    owner = self()

    server =
      serve(context.listener, owner, fn socket ->
        :gen_tcp.send(
          socket,
          "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\ncontent-length: 4\r\ncontent-length: 5\r\n\r\npage"
        )
      end)

    target = target(context.port)

    assert {:error, :request_failed} =
             Mint.request(target, {127, 0, 0, 1}, limits(), nil)

    assert_receive {:request, _request}
    assert Task.await(server) == :ok
  end

  test "closes the socket after a response deadline", context do
    owner = self()

    server =
      serve(context.listener, owner, fn socket ->
        send(owner, {:closed_result, :gen_tcp.recv(socket, 0, 2_000)})
      end)

    target = target(context.port)

    assert {:error, :timeout} =
             Mint.request(target, {127, 0, 0, 1}, limits(1_024, 250), nil)

    assert_receive {:request, _request}
    assert_receive {:closed_result, {:error, :closed}}, 1_000
    assert Task.await(server) == :ok
  end

  defp serve(listener, owner, response) do
    Task.async(fn ->
      {:ok, socket} = :gen_tcp.accept(listener)
      {:ok, request} = receive_headers(socket, "")
      send(owner, {:request, String.downcase(request)})
      response.(socket)
      :gen_tcp.close(socket)
      :ok
    end)
  end

  defp receive_headers(socket, received) do
    case :binary.match(received, "\r\n\r\n") do
      :nomatch -> receive_more_headers(socket, received)
      {_offset, _length} -> {:ok, received}
    end
  end

  defp receive_more_headers(socket, received) when byte_size(received) <= 8_192 do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, bytes} -> receive_headers(socket, received <> bytes)
      {:error, reason} -> {:error, reason}
    end
  end

  defp receive_more_headers(_socket, _received) do
    {:error, :too_large}
  end

  defp send_page(socket) do
    :gen_tcp.send(
      socket,
      "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\ncontent-length: 4\r\nconnection: close\r\n\r\npage"
    )
  end

  defp target(port) do
    {:ok, target} = Target.new("http://example.com:#{port}/path?query=visible")
    target
  end

  defp limits(maximum \\ 1_024, timeout \\ 1_000) do
    %Limits{max_response_bytes: maximum, timeout_ms: timeout}
  end
end
