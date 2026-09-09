defmodule Draught.Execution.RunnerTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Execution.Runner
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Fake
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Builtin.ReadFile
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

  defmodule AllowPolicy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(_request, _configuration) do
      Decision.new(outcome: :allow)
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

  test "streams ordered provider events before the retained result", %{tmp_dir: workspace} do
    registry = registry([])
    user = user("work")
    request = request([user], registry)
    final = response("done")
    first = delta("do")
    second = delta("ne")
    provider = fake_stream([stream_route(request, [first, second], {:ok, final})])

    assert run(provider, registry, workspace, request, provider_mode: :stream) == {:ok, final}

    assert receive_events(4) == [
             {:provider_event, 1, first},
             {:provider_event, 1, second},
             {:provider_result, 1, {:ok, final}},
             {:terminal, {:ok, final}}
           ]
  end

  test "streams tool calls before executing their canonical result", %{tmp_dir: workspace} do
    registry = registry([echo_definition()])
    user = user("work")
    first_request = request([user], registry)
    call = call("call-1", "echo", %{"value" => "first"})
    streamed_call = tool_call(call)
    tools = tool_response([call])
    first_result = result(call, "echo:first")
    second_request = request([user, tools.message, tool_message(first_result)], registry)
    final = response("done")
    final_delta = delta("done")

    provider =
      fake_stream([
        stream_route(first_request, [streamed_call], {:ok, tools}),
        stream_route(second_request, [final_delta], {:ok, final})
      ])

    assert run(provider, registry, workspace, first_request, provider_mode: :stream) ==
             {:ok, final}

    assert receive_events(6) == [
             {:provider_event, 1, streamed_call},
             {:provider_result, 1, {:ok, tools}},
             {:tool_result, 1, first_result},
             {:provider_event, 2, final_delta},
             {:provider_result, 2, {:ok, final}},
             {:terminal, {:ok, final}}
           ]
  end

  test "bounds cumulative streamed output before delivery", %{tmp_dir: workspace} do
    registry = registry([])
    request = request([user("work")], registry)
    final = response("done")
    first = delta("first")
    second = delta("second")

    provider = fake_stream([stream_route(request, [first, second], {:ok, final})])

    maximum_bytes = :erlang.external_size(first) + :erlang.external_size(second) - 1
    limits = limits(max_output_bytes: maximum_bytes)

    assert {:error, error} =
             run(provider, registry, workspace, request,
               provider_mode: :stream,
               limits: limits
             )

    assert error.code == "provider_output_too_large"

    assert receive_events(3) == [
             {:provider_event, 1, first},
             {:provider_result, 1, {:error, error}},
             {:terminal, {:error, error}}
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

  test "enforces the same deadline in streaming mode", %{tmp_dir: workspace} do
    registry = registry([])
    request = request([user("work")], registry)
    limits = limits(provider_timeout_ms: 10)
    provider = {SlowProvider, nil}

    assert {:error, error} =
             run(provider, registry, workspace, request,
               limits: limits,
               provider_mode: :stream
             )

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

  test "returns a repeated semantic tool batch as recoverable feedback", %{tmp_dir: workspace} do
    registry = registry([echo_definition()])
    user = user("work")
    first_request = request([user], registry)
    first = call("call-1", "echo", %{"value" => "same"})
    first_tools = tool_response([first])
    first_result = result(first, "echo:same")
    second_request = request([user, first_tools.message, tool_message(first_result)], registry)
    repeated = call("call-2", "echo", %{"value" => "same"})
    repeated_tools = tool_response([repeated])

    feedback =
      error_result(
        repeated,
        :policy,
        "duplicate_tool_call",
        "Repeated tool call was not executed",
        "This exact tool call was already attempted earlier in this turn. " <>
          "Reuse its result or change the request."
      )

    third_request =
      request(
        [
          user,
          first_tools.message,
          tool_message(first_result),
          repeated_tools.message,
          tool_message(feedback)
        ],
        registry
      )

    final = response("used the existing result")

    provider =
      fake([
        route(first_request, {:ok, first_tools}),
        route(second_request, {:ok, repeated_tools}),
        route(third_request, {:ok, final})
      ])

    assert run(provider, registry, workspace, first_request) == {:ok, final}

    assert receive_events(6) == [
             {:provider_result, 1, {:ok, first_tools}},
             {:tool_result, 1, first_result},
             {:provider_result, 2, {:ok, repeated_tools}},
             {:tool_result, 2, feedback},
             {:provider_result, 3, {:ok, final}},
             {:terminal, {:ok, final}}
           ]
  end

  test "reads the same file again to verify a successful approved edit", %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")
    {:ok, read_definition} = ReadFile.definition()
    {:ok, write_definition} = ReplaceInFile.definition()
    registry = registry([read_definition, write_definition])
    user = user("edit and verify")
    initial = request([user], registry)
    first = call("read-1", "read_file", %{"path" => "sample.txt"})
    repeated = call("read-2", "read_file", %{"path" => "sample.txt"})

    edit =
      call("edit", "replace_in_file", %{
        "expected" => "before",
        "path" => "sample.txt",
        "replacement" => "after"
      })

    steps = [{first, "before"}, {edit, "Replaced one occurrence"}, {repeated, "after"}]

    {routes, messages} =
      Enum.map_reduce(steps, [user], fn {call, content}, messages ->
        tools = tool_response([call])
        request = request(messages, registry)
        result = result(call, content)
        next_messages = messages ++ [tools.message, tool_message(result)]
        {route(request, {:ok, tools}), next_messages}
      end)

    final = response("verified")
    final_request = request(messages, registry)
    final_route = route(final_request, {:ok, final})

    provider =
      routes
      |> Enum.concat([final_route])
      |> fake()

    approved_context = %{context(workspace, [:read, :write]) | approval: {AllowPolicy, nil}}

    assert run(provider, registry, workspace, initial, context: approved_context) == {:ok, final}
    assert File.read!(path) == "after"
    events = receive_events(8)
    verified = result(repeated, "after")
    assert {:tool_result, 3, verified} in events

    File.write!(path, "before")
    bounded = limits(max_iterations: 3)

    assert {:error, error} =
             run(provider, registry, workspace, initial,
               context: approved_context,
               limits: bounded
             )

    assert error.code == "iteration_limit"
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
      provider_mode: Keyword.get(options, :provider_mode, :complete),
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

  defp fake_stream(routes) do
    streams =
      Enum.map(routes, fn {request, events, result} ->
        %{request: request, events: events, result: result}
      end)

    {:ok, fake} = Fake.new(streams: streams)
    {Fake, fake}
  end

  defp route(request, result) do
    {request, result}
  end

  defp stream_route(request, events, result) do
    {request, events, result}
  end

  defp delta(content) do
    {:ok, delta} = Delta.new(kind: :text, content: content)
    delta
  end

  defp tool_call(call) do
    {:ok, event} = ToolCall.new(call: call)
    event
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

  defp error_result(call, kind, code, message, content \\ "") do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)

    {:ok, result} =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: content,
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
