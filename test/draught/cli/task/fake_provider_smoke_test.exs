defmodule Draught.CLI.Task.FakeProviderSmokeTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Provider.Fake
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Call
  alias Draught.Tool.Registry
  alias Draught.Tool.Result

  @moduletag :tmp_dir

  test "performs an approved edit and verifies it with the standard tools", %{
    tmp_dir: workspace
  } do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")

    assert {:ok, template_provider} = Fake.new()
    assert {:ok, template_selection} = Selection.new({Fake, template_provider}, "free-model")

    assert {:ok, template} =
             Preparation.new("Update sample.txt", template_selection, workspace, risk: :allow)

    tools = Registry.specifications(template.runner.registry)
    first_request = request(template.request.messages, tools)

    replace =
      call("replace-1", "replace_in_file", %{
        "expected" => "before",
        "path" => "sample.txt",
        "replacement" => "after"
      })

    replace_response = tool_response([replace])
    replaced = result(replace, "Replaced one occurrence")

    second_request =
      request(
        template.request.messages ++ [replace_response.message, tool_message(replaced)],
        tools
      )

    read = call("read-1", "read_file", %{"path" => "sample.txt"})
    read_response = tool_response([read])
    read_result = result(read, "after")

    third_request =
      request(
        second_request.messages ++ [read_response.message, tool_message(read_result)],
        tools
      )

    final = response("Updated and verified sample.txt")

    provider =
      fake([
        {first_request, {:ok, replace_response}},
        {second_request, {:ok, read_response}},
        {third_request, {:ok, final}}
      ])

    assert {:ok, selection} = Selection.new(provider, "free-model")

    assert {:ok, preparation} =
             Preparation.new("Update sample.txt", selection, workspace, risk: :allow)

    assert {:ok, ^final} = OneShot.run(unique_id(), preparation)
    assert File.read!(path) == "after"
  end

  test "returns an approval requirement to the model without changing the file", %{
    tmp_dir: workspace
  } do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")

    assert {:ok, template_provider} = Fake.new()
    assert {:ok, template_selection} = Selection.new({Fake, template_provider}, "free-model")
    assert {:ok, template} = Preparation.new("Update", template_selection, workspace, risk: :ask)

    tools = Registry.specifications(template.runner.registry)
    first_request = request(template.request.messages, tools)

    replace =
      call("replace-1", "replace_in_file", %{
        "expected" => "before",
        "path" => "sample.txt",
        "replacement" => "after"
      })

    proposal = tool_response([replace])
    denied = error_result(replace, "approval_required", "Tool execution requires approval")

    second_request =
      request(template.request.messages ++ [proposal.message, tool_message(denied)], tools)

    final = response("The edit requires approval")
    provider = fake([{first_request, {:ok, proposal}}, {second_request, {:ok, final}}])

    assert {:ok, selection} = Selection.new(provider, "free-model")
    assert {:ok, preparation} = Preparation.new("Update", selection, workspace, risk: :ask)
    assert {:ok, ^final} = OneShot.run(unique_id(), preparation)
    assert File.read!(path) == "before"
  end

  defp request(messages, tools) do
    {:ok, request} = Request.new(model: "free-model", messages: messages, tools: tools)
    request
  end

  defp call(id, name, arguments) do
    {:ok, call} = Call.new(id: id, name: name, arguments: arguments)
    call
  end

  defp tool_response(calls) do
    {:ok, message} = Conversation.assistant(tool_calls: calls)
    {:ok, response} = Response.new(message: message, finish_reason: :tool_calls)
    response
  end

  defp response(content) do
    {:ok, message} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: message, finish_reason: :stop)
    response
  end

  defp result(call, content) do
    {:ok, result} =
      Result.new(call_id: call.id, name: call.name, content: content, status: :success)

    result
  end

  defp error_result(call, code, message) do
    {:ok, error} = Normalized.new(:policy, code, message, retryable: false)

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

  defp fake(routes) do
    completions =
      Enum.map(routes, fn {request, result} ->
        %{request: request, result: result}
      end)

    {:ok, provider} = Fake.new(completions: completions)
    {Fake, provider}
  end

  defp unique_id do
    value = System.unique_integer([:positive, :monotonic])
    "fake-smoke-#{value}"
  end
end
