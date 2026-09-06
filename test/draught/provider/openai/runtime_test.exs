defmodule Draught.Provider.OpenAI.RuntimeTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.OpenAI.Transport.Request.Builder
  alias Draught.Provider.Request
  alias Draught.Validation.Error

  defmodule StubTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    @impl Draught.Provider.OpenAI.Transport
    def complete(_request, _config) do
      :unused
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(_request, _config, _initial, _reducer) do
      :unused
    end
  end

  test "builds a redacted runtime with the default or an injected transport" do
    assert {:ok, runtime} = Runtime.new(credential: "secret")
    assert runtime.transport_module == Draught.Provider.OpenAI.Transport.Req
    assert runtime.transport_config == nil
    assert inspect(runtime) == "#Draught.Provider.OpenAI.Runtime<redacted>"
    refute inspect(runtime) =~ "secret"

    assert {:ok, runtime} = Runtime.new(%{}, {StubTransport, :transport_config})
    assert runtime.transport_module == StubTransport
    assert runtime.transport_config == :transport_config
  end

  test "rejects malformed transport dependencies" do
    invalid = [:invalid, {String, nil}, {StubTransport}, {"module", nil}]

    Enum.each(invalid, fn transport ->
      assert {:error, %Error{}} = Runtime.new(%{}, transport)
    end)
  end

  test "builds complete and stream transport requests from canonical values" do
    assert {:ok, configuration} =
             Configuration.new(
               base_url: "https://example.test/v1/",
               credential: "token",
               headers: %{"x-trace" => "enabled"},
               model: "configured-model",
               timeouts: %{connect_ms: 10, receive_ms: 20, request_ms: 30},
               limits: %{max_response_bytes: 2_048}
             )

    request = request()

    assert {:ok, complete} = Builder.build(request, configuration, :complete)
    assert complete.url == "https://example.test/v1/chat/completions"
    assert complete.headers == %{"authorization" => "Bearer token", "x-trace" => "enabled"}
    assert complete.body["model"] == "configured-model"
    refute Map.has_key?(complete.body, "stream")
    assert complete.connect_timeout_ms == 10
    assert complete.receive_timeout_ms == 20
    assert complete.request_timeout_ms == 30
    assert complete.max_response_bytes == 2_048

    assert {:ok, stream} = Builder.build(request, configuration, :stream)
    assert stream.body["stream"] == true
    assert stream.body["stream_options"] == %{"include_usage" => true}
  end

  defp request do
    assert {:ok, user} = Conversation.user("Hello")

    assert {:ok, request} =
             Request.new(
               model: "request-model",
               messages: [user],
               options: %{max_output_tokens: 32}
             )

    request
  end
end
