defmodule Draught.TelemetryTest do
  use ExUnit.Case, async: false

  alias Draught.Conversation
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Session
  alias Draught.Telemetry
  alias Draught.Telemetry.Capture
  alias Draught.Tool
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Output
  alias Draught.Tool.Registry
  alias Draught.Tool.Result.Provenance

  @receive_timeout 1_000
  @moduletag :tmp_dir

  defmodule TestProvider do
    @behaviour Provider

    @impl Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true)
    end

    @impl Provider
    def complete(_request, %{action: :raise, secret: secret}) do
      raise "provider failed with #{secret}"
    end

    def complete(_request, %{action: :block, owner: owner}) do
      send(owner, {:blocking_provider, self()})
      Process.sleep(:infinity)
    end

    def complete(_request, %{response: response}) do
      {:ok, response}
    end

    @impl Provider
    def stream(request, configuration, _sink) do
      complete(request, configuration)
    end
  end

  defmodule TestExecutor do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(_call, _context, %{action: :raise, secret: secret}) do
      raise "tool failed with #{secret}"
    end

    def execute(_call, _context, %{output: output}) do
      {:ok, output}
    end
  end

  test "emits paired provider spans with bounded usage and allowlisted metadata" do
    token = attach(:provider)
    secret = "provider-secret-value"
    request = request("prompt-secret-value")
    response = response("response-secret-value", large_usage())

    assert {:ok, ^response} = Provider.complete({TestProvider, %{response: response}}, request)

    assert_receive {Capture, ^token, [:draught, :provider, :request, :start], start,
                    %{operation: :complete}},
                   @receive_timeout

    assert is_integer(start.system_time)

    assert_receive {Capture, ^token, [:draught, :provider, :request, :stop], measurements,
                    metadata},
                   @receive_timeout

    assert measurements.count == 1
    assert is_integer(measurements.duration)
    assert measurements.input_tokens == Telemetry.maximum_count()
    assert measurements.output_tokens == Telemetry.maximum_count()
    assert measurements.total_tokens == Telemetry.maximum_count()
    assert metadata == %{error_kind: nil, operation: :complete, outcome: :ok}

    emitted = inspect({start, measurements, metadata})
    refute emitted =~ secret
    refute emitted =~ "prompt-secret-value"
    refute emitted =~ "response-secret-value"
  end

  test "emits sanitized exception completion and re-raises provider defects" do
    token = attach(:provider)
    secret = "credential-in-exception"

    assert_raise RuntimeError, fn ->
      Provider.complete({TestProvider, %{action: :raise, secret: secret}}, request("private"))
    end

    assert_receive {Capture, ^token, [:draught, :provider, :request, :start], _, _},
                   @receive_timeout

    assert_receive {Capture, ^token, [:draught, :provider, :request, :exception], measurements,
                    metadata},
                   @receive_timeout

    assert measurements.count == 1
    assert is_integer(measurements.duration)
    assert metadata == %{exception_kind: :error, operation: :complete, outcome: :exception}
    refute inspect({measurements, metadata}) =~ secret
  end

  test "a killed provider owner still produces one sanitized exception completion" do
    token = attach(:provider)

    task =
      Task.async(fn ->
        Provider.complete(
          {TestProvider, %{action: :block, owner: self()}},
          request("private")
        )
      end)

    assert_receive {Capture, ^token, [:draught, :provider, :request, :start], _, _},
                   @receive_timeout

    Task.shutdown(task, :brutal_kill)

    assert_receive {Capture, ^token, [:draught, :provider, :request, :exception], measurements,
                    metadata},
                   @receive_timeout

    assert measurements.count == 1
    assert metadata == %{exception_kind: :exit, operation: :complete, outcome: :exception}
    refute_receive {Capture, ^token, [:draught, :provider, :request, :stop], _, _}, 50
  end

  test "emits tool stop and exception events without names, arguments, or output" do
    token = attach(:tool)
    secret = "tool-secret-value"
    registry = registry(%{output: secret})

    assert {:ok, result} = Tool.execute(registry, call(secret), context())
    assert result.content == secret

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :start], _, %{}},
                   @receive_timeout

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :stop], measurements,
                    metadata},
                   @receive_timeout

    assert measurements.count == 1
    assert metadata == %{error_kind: nil, outcome: :ok}
    refute inspect({measurements, metadata}) =~ secret
    refute inspect(metadata) =~ "read_private_file"

    raising = registry(%{action: :raise, secret: secret})

    assert_raise RuntimeError, fn ->
      Tool.execute(raising, call(secret), context())
    end

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :start], _, %{}},
                   @receive_timeout

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :exception], _, exception},
                   @receive_timeout

    assert exception == %{exception_kind: :error, outcome: :exception}
    refute inspect(exception) =~ secret
  end

  test "projects web trust without exposing provenance sources" do
    token = attach(:tool)

    {:ok, provenance} =
      Provenance.new(
        origin: :web,
        trust: :untrusted,
        sources: ["https://example.com/private?secret=value"]
      )

    {:ok, output} = Output.new(content: "external data", provenance: provenance)
    registry = registry(%{output: output})

    assert {:ok, result} = Tool.execute(registry, call("private query"), context())
    assert result.provenance.trust == :untrusted

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :start], _, %{}},
                   @receive_timeout

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :stop], _, metadata},
                   @receive_timeout

    assert metadata == %{error_kind: nil, origin: :web, outcome: :ok, trust: :untrusted}
    refute inspect(metadata) =~ "example.com"
    refute inspect(metadata) =~ "private query"
  end

  test "identifies failed web operations without exposing outbound data" do
    token = attach(:tool)

    {:ok, definition} =
      Definition.new(
        name: "web_search",
        description: "Test web search",
        input_schema: %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{},
          "required" => []
        },
        risk: :network,
        executor: {TestExecutor, %{output: "unused"}}
      )

    {:ok, registry} = Registry.new([definition])
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, web_context} = Context.new(workspace: "/workspace/project", policy: policy)
    call = %{id: "private-call-id", name: "web_search", arguments: %{}}

    assert {:ok, result} = Tool.execute(registry, call, web_context)
    assert result.status == :error

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :start], _, %{}},
                   @receive_timeout

    assert_receive {Capture, ^token, [:draught, :tool, :execution, :stop], _, metadata},
                   @receive_timeout

    assert metadata == %{error_kind: :policy, origin: :web, outcome: :error, trust: :untrusted}
    refute inspect(metadata) =~ "private-call-id"
  end

  test "pairs one session turn span through asynchronous completion", %{tmp_dir: workspace} do
    token = attach(:session)
    id = "private-session-#{System.unique_integer([:positive])}"
    final = response("private response", nil)
    configuration = runner_configuration(workspace, final)

    assert {:ok, _session} = Session.start(id, configuration, journal: false)

    on_exit(fn ->
      Session.stop(id)
    end)

    assert {:ok, 1} = Session.run(id, request("private prompt"), self())

    assert_receive {Capture, ^token, [:draught, :session, :turn, :start], start, %{}},
                   @receive_timeout

    assert is_integer(start.system_time)
    assert_receive {:draught_session, ^id, {:turn_terminal, 1, {:ok, ^final}}}, @receive_timeout

    assert_receive {Capture, ^token, [:draught, :session, :turn, :stop], measurements, metadata},
                   @receive_timeout

    assert measurements.count == 1
    assert metadata == %{error_kind: nil, outcome: :ok}
    refute inspect({measurements, metadata}) =~ id
    refute inspect({measurements, metadata}) =~ "private"
  end

  defp attach(domain) do
    {:ok, token} = Capture.attach(self(), Telemetry.events(domain))

    on_exit(fn ->
      Capture.detach(token)
    end)

    token
  end

  defp request(content) do
    {:ok, user} = Conversation.user(content)
    {:ok, request} = Request.new(model: "https://private-model.example", messages: [user])
    request
  end

  defp response(content, usage) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop, usage: usage)
    response
  end

  defp large_usage do
    count = Telemetry.maximum_count() + 1

    {:ok, usage} =
      Usage.new(
        input_tokens: count,
        output_tokens: count,
        cached_tokens: count,
        reasoning_tokens: count
      )

    usage
  end

  defp registry(configuration) do
    {:ok, definition} =
      Definition.new(
        name: "read_private_file",
        description: "Read one private file",
        input_schema: %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{"path" => %{"type" => "string"}},
          "required" => ["path"]
        },
        risk: :read,
        executor: {TestExecutor, configuration}
      )

    {:ok, registry} = Registry.new([definition])
    registry
  end

  defp call(secret) do
    %{id: "private-call-id", name: "read_private_file", arguments: %{"path" => secret}}
  end

  defp context do
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, context} = Context.new(workspace: "/workspace/project", policy: policy)
    context
  end

  defp runner_configuration(workspace, final) do
    {:ok, registry} = Registry.new([])
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, context} = Context.new(workspace: workspace, policy: policy)
    {:ok, limits} = Limits.new(provider_timeout_ms: 5_000)

    [
      provider: {TestProvider, %{response: final}},
      registry: registry,
      tool_context: context,
      limits: limits
    ]
  end
end
