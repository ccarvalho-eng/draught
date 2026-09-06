defmodule Draught.Provider.OpenAI.Transport.ReqTest do
  use ExUnit.Case, async: true

  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.OpenAI.Transport.Req
  alias Draught.Provider.OpenAI.Transport.Request

  defmodule TestClient do
    alias Elixir.Req.HTTPError
    alias Elixir.Req.Response
    alias Elixir.Req.TransportError

    @spec stream_response(keyword(), non_neg_integer(), [binary()]) :: Response.t()
    def stream_response(options, status, chunks) do
      into = Keyword.fetch!(options, :into)
      initial_response = Response.new(status: status)

      {_request, final_response} =
        Enum.reduce_while(chunks, {nil, initial_response}, fn chunk, accumulator ->
          into.({:data, chunk}, accumulator)
        end)

      final_response
    end

    @spec failure(atom()) :: Exception.t()
    def failure(:timeout) do
      %TransportError{reason: :timeout}
    end

    def failure(:connection_refused) do
      %TransportError{reason: :econnrefused}
    end

    def failure(:closed) do
      %TransportError{reason: :closed}
    end

    def failure(:unprocessed) do
      %HTTPError{protocol: :http2, reason: :unprocessed}
    end

    def failure(:unknown) do
      %RuntimeError{message: "sensitive detail"}
    end
  end

  test "posts JSON with fixed transport safety options and a bounded complete body" do
    parent = self()

    client = fn options ->
      send(parent, {:options, options})
      response = TestClient.stream_response(options, 200, [~s({"ok":), "true}"])
      {:ok, response}
    end

    assert {:ok, response} = Req.complete(request(), client)
    assert response.status == 200
    assert response.body == ~s({"ok":true})

    assert_receive {:options, options}
    assert options[:method] == :post
    assert options[:url] == "https://example.test/v1/chat/completions"
    assert options[:json] == %{"model" => "test"}
    assert options[:headers] == %{"authorization" => "Bearer token"}
    assert options[:retry] == false
    assert options[:redirect] == false
    assert options[:decode_body] == false
    assert options[:connect_options] == [timeout: 10]
    assert options[:receive_timeout] == 20
    assert options[:request_timeout] == 30
  end

  test "rejects an oversized successful complete body without retaining it" do
    client = fn options ->
      {:ok, TestClient.stream_response(options, 200, ["1234", "5"])}
    end

    bounded_request = request(max_response_bytes: 4)

    assert {:error, %Failure{reason: :response_too_large}} =
             Req.complete(bounded_request, client)
  end

  test "does not retain provider error bodies" do
    client = fn options ->
      {:ok, TestClient.stream_response(options, 429, ["sensitive provider payload"])}
    end

    assert {:ok, response} = Req.complete(request(), client)
    assert response.status == 429
    assert response.body == nil
  end

  test "streams successful chunks through the reducer and returns its state" do
    client = fn options ->
      {:ok, TestClient.stream_response(options, 200, ["one", "two"])}
    end

    reducer = fn data, values ->
      {:cont, [data | values], data == "two"}
    end

    assert {:ok, response, values} = Req.stream(request(), client, [], reducer)
    assert response.status == 200
    assert values == ["two", "one"]
  end

  test "preserves reducer state when the reducer halts" do
    client = fn options ->
      {:ok, TestClient.stream_response(options, 200, ["one", "stop", "ignored"])}
    end

    reducer = fn
      "stop", values -> {:halt, ["stop" | values], false}
      data, values -> {:cont, [data | values], false}
    end

    assert {:ok, _response, ["stop", "one"]} =
             Req.stream(request(), client, [], reducer)
  end

  test "ignores non-success stream bodies" do
    parent = self()

    client = fn options ->
      {:ok, TestClient.stream_response(options, 503, ["not SSE"])}
    end

    reducer = fn _data, state ->
      send(parent, :reduced)
      {:cont, state, true}
    end

    assert {:ok, response, :initial} =
             Req.stream(request(), client, :initial, reducer)

    assert response.status == 503
    refute_received :reduced
  end

  test "classifies known Req failures and sanitizes unknown exceptions" do
    failures = [
      {TestClient.failure(:timeout), :timeout},
      {TestClient.failure(:connection_refused), :connection_refused},
      {TestClient.failure(:closed), :closed},
      {TestClient.failure(:unprocessed), :unprocessed},
      {TestClient.failure(:unknown), :unknown}
    ]

    Enum.each(failures, fn {exception, expected} ->
      client = fn _options -> {:error, exception} end

      assert {:error, %Failure{reason: ^expected}} = Req.complete(request(), client)
    end)

    client = fn _options -> {:error, TestClient.failure(:unknown)} end
    assert {:error, failure} = Req.complete(request(), client)
    refute inspect(failure) =~ "sensitive detail"
  end

  test "retains only the output marker when transport fails after streamed output" do
    client = fn options ->
      _response = TestClient.stream_response(options, 200, ["visible"])
      {:error, TestClient.failure(:closed)}
    end

    reducer = fn _data, state ->
      {:cont, state, true}
    end

    assert {:error, %Failure{reason: :closed}, true} =
             Req.stream(request(), client, :state, reducer)
  end

  defp request(overrides \\ []) do
    defaults = %{
      url: "https://example.test/v1/chat/completions",
      headers: %{"authorization" => "Bearer token"},
      body: %{"model" => "test"},
      connect_timeout_ms: 10,
      receive_timeout_ms: 20,
      request_timeout_ms: 30,
      max_response_bytes: 1_024
    }

    struct!(Request, Map.merge(defaults, Map.new(overrides)))
  end
end
