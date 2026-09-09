defmodule Draught.Execution.Runner.ToolBatch.ProgressTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.ToolBatch.Progress
  alias Draught.Tool.Builtin.ReadFile
  alias Draught.Tool.Builtin.ReplaceInFile
  alias Draught.Tool.Builtin.RunCommand
  alias Draught.Tool.Definition
  alias Draught.Tool.Registry
  alias Draught.Tool.Result

  setup do
    {:ok, read} = ReadFile.definition()
    {:ok, write} = ReplaceInFile.definition()
    {:ok, execute} = RunCommand.definition()
    {:ok, registry} = Registry.new([read, write, execute])
    read_key = [{"read_file", %{"path" => "sample.txt"}}]
    write_key = [{"replace_in_file", %{"path" => "sample.txt"}}]
    execute_key = [{"run_command", %{"executable" => "tool"}}]
    unknown_key = [{"unknown", %{}}]
    mixed_key = read_key ++ write_key
    retained = MapSet.new([write_key, execute_key, unknown_key, mixed_key])
    seen = MapSet.put(retained, read_key)
    %{registry: registry, retained: retained, seen: seen}
  end

  test "successful writes refresh only all-read batches", context do
    messages = [message("replace_in_file", :success)]
    assert Progress.refresh(context.seen, messages, context.registry) == context.retained
  end

  test "successful commands also permit checking potentially changed files", context do
    messages = [message("run_command", :success)]
    assert Progress.refresh(context.seen, messages, context.registry) == context.retained
  end

  test "failed mutations and successful reads cannot erase loop history", context do
    for {name, status} <- [
          {"replace_in_file", :error},
          {"run_command", :error},
          {"read_file", :success},
          {"unknown", :success}
        ] do
      messages = [message(name, status)]
      assert Progress.refresh(context.seen, messages, context.registry) == context.seen
    end
  end

  test "mixed results refresh reads when a mutation succeeded but retain failed batches",
       context do
    messages = [message("replace_in_file", :success), message("run_command", :error)]
    assert Progress.refresh(context.seen, messages, context.registry) == context.retained
  end

  test "tool names alone never establish mutation risk", context do
    {:ok, definition} = ReadFile.definition()

    {:ok, custom} =
      Definition.new(
        name: "replace_in_file",
        description: "A read-only integration",
        input_schema: definition.specification.input_schema,
        executor: definition.executor,
        risk: :read
      )

    {:ok, registry} = Registry.new([definition, custom])
    messages = [message("replace_in_file", :success)]
    assert Progress.refresh(context.seen, messages, registry) == context.seen
  end

  test "no trusted registry preserves conservative duplicate detection", context do
    messages = [message("replace_in_file", :success)]
    assert Progress.refresh(context.seen, messages, nil) == context.seen
  end

  test "retains duplicate guards only while their execution history remains present", context do
    assert Progress.retain(context.seen, context.retained) == context.retained
  end

  defp message(name, status) do
    {:ok, result} =
      Result.new(
        call_id: name,
        name: name,
        content: "",
        status: status,
        error: error(status)
      )

    {:ok, message} = Conversation.tool(result)
    message
  end

  defp error(:success) do
    nil
  end

  defp error(:error) do
    {:ok, error} = Normalized.new(:tool, "failed", "Tool failed")
    error
  end
end
