defmodule Draught.Execution.Runner.StateTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Conversation.Message
  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Limits
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.Transition
  alias Draught.Execution.Runner.Transition.Provider
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  test "completes with final assistant content" do
    state = initial_state()
    {:continue, waiting, sent_request} = Transition.next_request(state)

    assert sent_request.messages == state.messages
    assert {:ok, completed} = Provider.accept(waiting, {:ok, response("done")})
    assert {:ok, %Response{message: message}} = State.outcome(completed)
    content_part = List.first(message.content)
    assert Map.fetch!(content_part, :text) == "done"
  end

  test "appends one result for a tool call before the next request" do
    state = initial_state()
    {:continue, waiting, _request} = Transition.next_request(state)
    call = call("call-1", "read_file", %{"path" => "README.md"})

    assert {:ok, tools} = Provider.accept(waiting, {:ok, tool_response([call])})
    assert State.pending_calls(tools) == [call]
    assert {:ok, ready} = Transition.accept_tools(tools, [tool_message(call, "content")])
    assert {:continue, _waiting, next_request} = Transition.next_request(ready)

    assert Enum.map(next_request.messages, &Message.role/1) == [
             :user,
             :assistant,
             :tool
           ]
  end

  test "requires tool results in exact call order" do
    state = initial_state()
    {:continue, waiting, _request} = Transition.next_request(state)
    first = call("call-1", "read_file", %{"path" => "README.md"})
    second = call("call-2", "list_directory", %{"path" => "."})
    {:ok, tools} = Provider.accept(waiting, {:ok, tool_response([first, second])})

    assert {:error, error} =
             Transition.accept_tools(tools, [
               tool_message(second, "second"),
               tool_message(first, "first")
             ])

    assert List.first(error.violations).code == :invalid_relationship
  end

  test "rejects a non-list tool-result collection at the result boundary" do
    state = initial_state()
    {:continue, waiting, _request} = Transition.next_request(state)
    call = call("call-1", "read_file", %{"path" => "README.md"})
    {:ok, tools} = Provider.accept(waiting, {:ok, tool_response([call])})

    assert {:error, error} = Transition.accept_tools(tools, :invalid)
    assert List.first(error.violations).code == :invalid_type
  end

  test "stops a repeated semantic tool batch even when call IDs change" do
    state = initial_state()
    {:continue, first_wait, _request} = Transition.next_request(state)
    first = call("call-1", "read_file", %{"path" => "README.md"})
    {:ok, first_tools} = Provider.accept(first_wait, {:ok, tool_response([first])})
    {:ok, ready} = Transition.accept_tools(first_tools, [tool_message(first, "content")])
    {:continue, second_wait, _request} = Transition.next_request(ready)
    repeated = call("call-2", "read_file", %{"path" => "README.md"})

    assert {:ok, stopped} =
             Provider.accept(second_wait, {:ok, tool_response([repeated])})

    assert {:error, error} = State.outcome(stopped)
    assert error.code == "duplicate_tool_batch"
  end

  test "stops before exceeding the iteration limit" do
    state = initial_state(max_iterations: 1)
    {:continue, waiting, _request} = Transition.next_request(state)
    call = call("call-1", "read_file", %{"path" => "README.md"})
    {:ok, tools} = Provider.accept(waiting, {:ok, tool_response([call])})
    {:ok, ready} = Transition.accept_tools(tools, [tool_message(call, "content")])

    assert {:halt, stopped} = Transition.next_request(ready)
    assert {:error, error} = State.outcome(stopped)
    assert error.code == "iteration_limit"
  end

  test "retains a canonical provider failure as the terminal outcome" do
    state = initial_state()
    {:continue, waiting, _request} = Transition.next_request(state)
    {:ok, error} = Normalized.new(:transport, "offline", "Provider unavailable")

    assert {:ok, stopped} = Provider.accept(waiting, {:error, error})
    assert State.outcome(stopped) == {:error, error}
  end

  defp initial_state(limit_options \\ []) do
    {:ok, user} = Conversation.user("work")
    {:ok, request} = Request.new(model: "model", messages: [user])
    {:ok, limits} = Limits.new(limit_options)
    {:ok, state} = State.new(request, limits)
    state
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end

  defp tool_response(calls) do
    {:ok, assistant} = Conversation.assistant(tool_calls: calls)
    {:ok, response} = Response.new(message: assistant, finish_reason: :tool_calls)
    response
  end

  defp call(id, name, arguments) do
    {:ok, call} = Call.new(id: id, name: name, arguments: arguments)
    call
  end

  defp tool_message(call, content) do
    {:ok, result} =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: content,
        status: :success
      )

    {:ok, message} = Conversation.tool(result)
    message
  end
end
