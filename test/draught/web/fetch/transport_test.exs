defmodule Draught.Web.Fetch.TransportTest do
  use ExUnit.Case, async: true

  alias Draught.Web.Fetch.Transport.Mint
  alias Draught.Web.Network.AddressPolicy
  alias Draught.Web.Policy
  alias Draught.Web.Target

  defmodule Resolver do
    @behaviour Draught.Web.Network.Resolver

    @impl Draught.Web.Network.Resolver
    def resolve(host, function) do
      function.(host)
    end
  end

  defmodule Connection do
    @behaviour Draught.Web.Fetch.Transport.Connection

    @impl Draught.Web.Fetch.Transport.Connection
    def request(target, address, limits, function) do
      function.(target, address, limits)
    end
  end

  test "accepts only ordinary HTTP(S) targets without credentials" do
    assert {:ok, target} = Target.new("https://example.com:8443/path?q=one")
    assert target.scheme == :https
    assert target.host == "example.com"
    assert target.port == 8443
    assert target.request_target == "/path?q=one"

    for url <- [
          "file:///etc/passwd",
          "https://user:secret@example.com/",
          "https://example.com/#fragment",
          "https://2130706433/",
          "https://0x7f000001/"
        ] do
      assert {:error, _error} = Target.new(url)
    end
  end

  test "allows public addresses and rejects local, special-use, and transition ranges" do
    assert :ok = AddressPolicy.validate({1, 1, 1, 1})
    assert :ok = AddressPolicy.validate({0x2606, 0x4700, 0x4700, 0, 0, 0, 0, 0x1111})

    blocked = [
      {0, 0, 0, 0},
      {10, 0, 0, 1},
      {100, 100, 100, 200},
      {127, 0, 0, 1},
      {169, 254, 169, 254},
      {172, 16, 0, 1},
      {192, 168, 0, 1},
      {224, 0, 0, 1},
      {0, 0, 0, 0, 0, 0, 0, 1},
      {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 1},
      {0xFC00, 0, 0, 0, 0, 0, 0, 1},
      {0xFE80, 0, 0, 0, 0, 0, 0, 1},
      {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1},
      {0x2002, 0x7F00, 1, 0, 0, 0, 0, 1}
    ]

    assert Enum.all?(blocked, &match?({:error, _error}, AddressPolicy.validate(&1)))
  end

  test "rejects a DNS answer set containing any private address before connecting" do
    owner = self()

    resolver = fn "example.com" ->
      {:ok, [{93, 184, 216, 34}, {127, 0, 0, 1}]}
    end

    connection = fn _target, _address, _limits ->
      send(owner, :connected)
      {:ok, response(200, "text/plain", "unexpected")}
    end

    assert {:error, error} =
             Mint.fetch("https://example.com", policy(), config(resolver, connection))

    assert error.code == "web_target_blocked"
    refute_received :connected
  end

  test "pins the validated address and revalidates every redirect target" do
    owner = self()

    resolver = fn
      "example.com" -> {:ok, [{93, 184, 216, 34}]}
      host -> flunk("unexpected resolver call for #{host}")
    end

    connection = fn target, address, _limits ->
      send(owner, {:connected, target.host, address})
      {:ok, response(302, "text/plain", "", [{"location", "https://127.0.0.1/private"}])}
    end

    assert {:error, error} =
             Mint.fetch("https://example.com", policy(), config(resolver, connection))

    assert error.code == "web_target_blocked"
    assert_received {:connected, "example.com", {93, 184, 216, 34}}
    refute_received {:connected, "127.0.0.1", _address}
  end

  test "returns a bounded canonical response without forwarding query provenance" do
    resolver = fn "example.com" -> {:ok, [{93, 184, 216, 34}]} end

    connection = fn target, address, limits ->
      assert target.host == "example.com"
      assert address == {93, 184, 216, 34}
      assert limits.max_response_bytes == 1_024
      {:ok, response(200, "text/plain; charset=utf-8", "page")}
    end

    assert {:ok, response} =
             Mint.fetch(
               "https://example.com/page?private=query",
               policy(),
               config(resolver, connection)
             )

    assert response.content == "page"
    assert response.final_url == "https://example.com/page"
    assert response.redirects == []
  end

  test "normalizes oversized and compressed response failures" do
    resolver = fn "example.com" -> {:ok, [{93, 184, 216, 34}]} end
    oversized = fn _target, _address, _limits -> {:error, :too_large} end

    assert {:error, too_large} =
             Mint.fetch(
               "https://example.com",
               policy(),
               config(resolver, oversized)
             )

    assert too_large.code == "web_response_too_large"

    compressed = fn _target, _address, _limits ->
      {:ok, response(200, "text/plain", "compressed", [{"content-encoding", "gzip"}])}
    end

    assert {:error, encoding} =
             Mint.fetch(
               "https://example.com",
               policy(),
               config(resolver, compressed)
             )

    assert encoding.code == "web_content_encoding_rejected"
  end

  test "rejects redirect loops, downgrades, malformed locations, and excessive chains" do
    resolver = fn "example.com" -> {:ok, [{93, 184, 216, 34}]} end

    redirects = [
      [{"location", "https://example.com"}],
      [{"location", "http://example.com/insecure"}],
      [],
      [{"location", "/one"}, {"location", "/two"}]
    ]

    Enum.each(redirects, fn headers ->
      connection = fn _target, _address, _limits ->
        {:ok, response(302, "text/plain", "", headers)}
      end

      assert {:error, error} =
               Mint.fetch("https://example.com", policy(), config(resolver, connection))

      assert error.code == "web_redirect_rejected"
    end)

    key = {:redirect_count, make_ref()}

    chain = fn _target, _address, _limits ->
      count = Process.get(key, 0) + 1
      Process.put(key, count)
      {:ok, response(302, "text/plain", "", [{"location", "/#{count}"}])}
    end

    assert {:error, excessive} =
             Mint.fetch("https://example.com", policy(), config(resolver, chain))

    assert excessive.code == "web_redirect_rejected"
  end

  test "resolves the hostname again before connecting after a redirect" do
    resolver_key = {:resolution_count, make_ref()}
    connection_key = {:connection_count, make_ref()}

    resolver = fn "example.com" ->
      count = Process.get(resolver_key, 0) + 1
      Process.put(resolver_key, count)

      case count do
        1 -> {:ok, [{93, 184, 216, 34}]}
        2 -> {:ok, [{127, 0, 0, 1}]}
      end
    end

    connection = fn _target, _address, _limits ->
      count = Process.get(connection_key, 0) + 1
      Process.put(connection_key, count)
      {:ok, response(302, "text/plain", "", [{"location", "/next"}])}
    end

    assert {:error, error} =
             Mint.fetch("https://example.com", policy(), config(resolver, connection))

    assert error.code == "web_target_blocked"
    assert Process.get(resolver_key) == 2
    assert Process.get(connection_key) == 1
  end

  test "distinguishes unsupported media types from malformed text" do
    resolver = fn "example.com" -> {:ok, [{93, 184, 216, 34}]} end

    unsupported = fn _target, _address, _limits ->
      {:ok, response(200, "application/octet-stream", "bytes")}
    end

    assert {:error, media_type} =
             Mint.fetch("https://example.com", policy(), config(resolver, unsupported))

    assert media_type.code == "web_content_type_rejected"

    malformed = fn _target, _address, _limits ->
      {:ok, response(200, "text/plain", <<255>>)}
    end

    assert {:error, content} =
             Mint.fetch("https://example.com", policy(), config(resolver, malformed))

    assert content.code == "web_content_invalid"
  end

  defp policy do
    {:ok, policy} =
      Policy.new(
        fetch: true,
        max_redirects: 2,
        max_response_bytes: 1_024,
        request_timeout_ms: 1_000,
        total_timeout_ms: 2_000
      )

    policy
  end

  defp config(resolver, connection) do
    [resolver: {Resolver, resolver}, connection: {Connection, connection}]
  end

  defp response(status, content_type, body, extra_headers \\ []) do
    %{
      status: status,
      headers: [{"content-type", content_type} | extra_headers],
      body: body
    }
  end
end
