defmodule Draught.Execution.RunnerTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Execution.Runner
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Fake
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Builtin.ReplaceInFile
  alias Draught.Tool.Call
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry
  alias Draught.Tool.Result

  @moduletag :tmp_dir

  defmodule EchoExecutor do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(call, _context, _configuration) do
      {:ok, "echo:#{call.arguments["value"]}"}
    end
  end

  defmodule SlowExecutor do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(_call, _context, _configuration) do
      Process.sleep(500)
      {:ok, "late"}
    end
  end

  defmodule SlowProvider do
    @behaviour Provider

    @impl Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true)
    end

    @impl Provider
    def complete(_request, _configuration) do
      Process.sleep(500)
      {:ok, :late}
    end

    @impl Provider
    def stream(_request, _configuration, _sink) do
      Process.sleep(500)
      {:ok, :late}
    end
  end

  test "returns final content and emits provider then terminal events", %{tmp_dir: workspace} do
    registry = registry([])
    user = user("work")
    request = request([user], registry)
    final = response("done")
    provider = fake([route(request, {:ok, final})])

    assert run(provider, registry, workspace, request) == {:ok, final}

    assert receive_events(2) == [
             {:provider_result, 1, {:ok, final}},
             {:terminal, {:ok, final}}
           ]
  end

  test "executes multiple calls in declaration order before continuing", %{tmp_dir: workspace} do
    registry = registry([echo_definition()])
    user = user("work")
    first_request = request([user], registry)
    first = call("call-1", "echo", %{"value" => "first"})
    second = call("call-2", "echo", %{"value" => "second"})
    tools = tool_response([first, second])
    first_result = result(first, "echo:first")
    second_result = result(second, "echo:second")

    second_request =
      request(
        [user, tools.message, tool_message(first_result), tool_message(second_result)],
        registry
      )

    final = response("done")
    provider = fake([route(first_request, {:ok, tools}), route(second_request, {:ok, final})])

    assert run(provider, registry, workspace, first_request) == {:ok, final}

    assert receive_events(5) == [
             {:provider_result, 1, {:ok, tools}},
             {:tool_result, 1, first_result},
             {:tool_result, 1, second_result},
             {:provider_result, 2, {:ok, final}},
             {:terminal, {:ok, final}}
           ]
  end

  test "returns default approval denial as a recoverable tool message", %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")
    {:ok, definition} = ReplaceInFile.definition()
    registry = registry([definition])
    user = user("work")
    first_request = request([user], registry)

    call =
      call("call-1", "replace_in_file", %{
        "expected" => "before",
        "path" => "sample.txt",
        "replacement" => "after"
      })

    tools = tool_response([call])
    denied = error_result(call, :policy, "approval_required", "Tool execution requires approval")
    second_request = request([user, tools.message, tool_message(denied)], registry)
    final = response("denied")
    provider = fake([route(first_request, {:ok, tools}), route(second_request, {:ok, final})])
    context = context(workspace, [:write])

    assert run(provider, registry, workspace, first_request, context: context) ==
             {:ok, final}

    assert File.read!(path) == "before"
  end

  test "returns an unknown tool as a recoverable tool message", %{tmp_dir: workspace} do
    registry = registry([])
    user = user("work")
    first_request = request([user], registry)
    call = call("call-1", "missing", %{})
    tools = tool_response([call])
    unknown = error_result(call, :tool, "unknown_tool", "Tool is not registered")
    second_request = request([user, tools.message, tool_message(unknown)], registry)
    final = response("recovered")
    provider = fake([route(first_request, {:ok, tools}), route(second_request, {:ok, final})])

    assert run(provider, registry, workspace, first_request) == {:ok, final}
  end

  test "returns provider failure as the terminal result", %{tmp_dir: workspace} do
    registry = registry([])
    request = request([user("work")], registry)
    {:ok, error} = Normalized.new(:transport, "offline", "Provider unavailable")
    provider = fake([route(request, {:error, error})])

    assert run(provider, registry, workspace, request) == {:error, error}

    assert receive_events(2) == [
             {:provider_result, 1, {:error, error}},
             {:terminal, {:error, error}}
           ]
  end

  test "enforces provider timeout", %{tmp_dir: workspace} do
    registry = registry([])
    request = request([user("work")], registry)
    limits = limits(provider_timeout_ms: 10)
    provider = {SlowProvider, nil}

    assert {:error, error} = run(provider, registry, workspace, request, limits: limits)

    assert error.code == "provider_timeout"
  end

  test "converts tool timeout into one recoverable result", %{tmp_dir: workspace} do
    registry = registry([slow_definition()])
    user = user("work")
    first_request = request([user], registry)
    call = call("call-1", "slow", %{})
    tools = tool_response([call])
    timeout = error_result(call, :timeout, "tool_timeout", "Tool exceeded the configured timeout")
    second_request = request([user, tools.message, tool_message(timeout)], registry)
    final = response("continued")
    provider = fake([route(first_request, {:ok, tools}), route(second_request, {:ok, final})])
    limits = limits(tool_timeout_ms: 10)

    assert run(provider, registry, workspace, first_request, limits: limits) == {:ok, final}
  end

  test "stops a repeated semantic tool batch", %{tmp_dir: workspace} do
    registry = registry([echo_definition()])
    user = user("work")
    first_request = request([user], registry)
    first = call("call-1", "echo", %{"value" => "same"})
    first_tools = tool_response([first])
    first_result = result(first, "echo:same")
    second_request = request([user, first_tools.message, tool_message(first_result)], registry)
    repeated = call("call-2", "echo", %{"value" => "same"})
    repeated_tools = tool_response([repeated])

    provider =
      fake([
        route(first_request, {:ok, first_tools}),
        route(second_request, {:ok, repeated_tools})
      ])

    assert {:error, error} = run(provider, registry, workspace, first_request)

    assert error.code == "duplicate_tool_batch"
  end

  test "stops when another provider iteration would exceed the limit", %{tmp_dir: workspace} do
    registry = registry([echo_definition()])
    user = user("work")
    first_request = request([user], registry)
    call = call("call-1", "echo", %{"value" => "once"})
    tools = tool_response([call])
    provider = fake([route(first_request, {:ok, tools})])
    limits = limits(max_iterations: 1)

    assert {:error, error} =
             run(provider, registry, workspace, first_request, limits: limits)

    assert error.code == "iteration_limit"
  end

  test "bounds retained provider output", %{tmp_dir: workspace} do
    registry = registry([])
    request = request([user("work")], registry)
    provider = fake([route(request, {:ok, response(String.duplicate("x", 256))})])
    limits = limits(max_output_bytes: 64)

    assert {:error, error} = run(provider, registry, workspace, request, limits: limits)

    assert error.code == "provider_output_too_large"
  end

  defp configuration(provider, registry, workspace, options) do
    owner = self()

    sink = fn event ->
      send(owner, {:event, event})
      :ok
    end

    configuration = [
      provider: provider,
      registry: registry,
      sink: sink,
      tool_context: Keyword.get(options, :context, context(workspace, [:read]))
    ]

    limit_value = Keyword.get(options, :limits, limits())
    Keyword.put_new(configuration, :limits, limit_value)
  end

  defp run(provider, registry, workspace, request, options \\ []) do
    configuration = configuration(provider, registry, workspace, options)
    Runner.run(configuration, request)
  end

  defp registry(definitions) do
    {:ok, registry} = Registry.new(definitions)
    registry
  end

  defp echo_definition do
    definition("echo", :read, EchoExecutor, %{
      "type" => "object",
      "properties" => %{"value" => %{"type" => "string"}},
      "required" => ["value"]
    })
  end

  defp slow_definition do
    definition("slow", :read, SlowExecutor, %{"type" => "object"})
  end

  defp definition(name, risk, executor, schema) do
    {:ok, definition} =
      Definition.new(
        name: name,
        description: "Test tool",
        input_schema: schema,
        risk: risk,
        executor: {executor, nil}
      )

    definition
  end

  defp context(workspace, risks) do
    {:ok, policy} = Policy.new(allowed_risks: risks)
    {:ok, context} = Context.new(workspace: workspace, policy: policy)
    context
  end

  defp limits(options \\ []) do
    {:ok, limits} = Limits.new(options)
    limits
  end

  defp request(messages, registry) do
    {:ok, request} =
      Request.new(model: "model", messages: messages, tools: Registry.specifications(registry))

    request
  end

  defp fake(routes) do
    completions =
      Enum.map(routes, fn {request, result} -> %{request: request, result: result} end)

    {:ok, fake} = Fake.new(completions: completions)
    {Fake, fake}
  end

  defp route(request, result) do
    {request, result}
  end

  defp user(content) do
    {:ok, message} = Conversation.user(content)
    message
  end

  defp response(content) do
    {:ok, message} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: message, finish_reason: :stop)
    response
  end

  defp tool_response(calls) do
    {:ok, message} = Conversation.assistant(tool_calls: calls)
    {:ok, response} = Response.new(message: message, finish_reason: :tool_calls)
    response
  end

  defp call(id, name, arguments) do
    {:ok, call} = Call.new(id: id, name: name, arguments: arguments)
    call
  end

  defp result(call, content) do
    {:ok, result} =
      Result.new(call_id: call.id, name: call.name, content: content, status: :success)

    result
  end

  defp error_result(call, kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)

    {:ok, result} =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: "",
        status: :error,
        error: error
      )

    result
  end

  defp tool_message(result) do
    {:ok, message} = Conversation.tool(result)
    message
  end

  defp receive_events(count) do
    Enum.map(1..count, fn _index ->
      receive do
        {:event, event} -> event
      after
        1_000 -> flunk("runner event was not received")
      end
    end)
  end
end
