defmodule Draught.Tool.Execution.InvocationTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Tool
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  defmodule Executor do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(call, context, configuration) do
      send(configuration.owner, {:executed, call, context})
      configuration.result
    end
  end

  test "executes validated arguments with the explicit context" do
    context = context([:read])
    registry = registry(:read, {:ok, "contents"})

    assert {:ok, result} =
             Tool.execute(registry, call(%{"path" => "README.md"}), context)

    assert result.status == :success
    assert result.content == "contents"
    assert result.error == nil
    assert_received {:executed, executed_call, ^context}
    assert executed_call.arguments == %{"path" => "README.md"}
  end

  test "returns an error result for an unknown tool" do
    registry = registry(:read, {:ok, "unused"})

    assert {:ok, result} =
             Tool.execute(registry, call(%{"path" => "README.md"}, "missing"), context([:read]))

    assert result.status == :error
    assert result.error.kind == :tool
    assert result.error.code == "unknown_tool"
    refute_received {:executed, _, _}
  end

  test "denies risks excluded by policy before dispatch" do
    registry = registry(:write, {:ok, "unused"})

    assert {:ok, result} =
             Tool.execute(registry, call(%{"path" => "README.md"}), context([:read]))

    assert result.status == :error
    assert result.error.kind == :policy
    assert result.error.code == "tool_risk_denied"
    refute_received {:executed, _, _}
  end

  test "rejects missing, extra, and incorrectly typed arguments before dispatch" do
    registry = registry(:read, {:ok, "unused"})

    for arguments <- [%{}, %{"path" => 123}, %{"path" => "README.md", "extra" => true}] do
      assert {:ok, result} = Tool.execute(registry, call(arguments), context([:read]))
      assert result.status == :error
      assert result.error.code == "invalid_arguments"
    end

    refute_received {:executed, _, _}
  end

  test "preserves canonical executor failures for the runner" do
    {:ok, failure} =
      Normalized.new(:tool, "read_failed", "File could not be read", retryable: false)

    registry = registry(:read, {:error, failure})

    assert {:ok, result} =
             Tool.execute(registry, call(%{"path" => "README.md"}), context([:read]))

    assert result.status == :error
    assert result.error == failure
  end

  test "normalizes malformed executor returns and oversized output" do
    malformed = registry(:read, :unexpected)

    assert {:ok, malformed_result} =
             Tool.execute(malformed, call(%{"path" => "README.md"}), context([:read]))

    assert malformed_result.error.code == "invalid_tool_result"

    oversized = registry(:read, {:ok, "12345"})

    assert {:ok, oversized_result} =
             Tool.execute(
               oversized,
               call(%{"path" => "README.md"}),
               context([:read], max_output_bytes: 4)
             )

    assert oversized_result.error.code == "tool_output_too_large"
  end

  test "rejects invalid call and context values at the public boundary" do
    registry = registry(:read, {:ok, "unused"})

    assert {:error, %Normalized{kind: :configuration, code: "invalid_tool_call"}} =
             Tool.execute(registry, %{name: "read_file"}, context([:read]))

    assert {:error, %Normalized{kind: :configuration, code: "invalid_tool_context"}} =
             Tool.execute(registry, call(%{"path" => "README.md"}), %{workspace: "relative"})
  end

  defp registry(risk, result) do
    {:ok, definition} =
      Definition.new(
        name: "read_file",
        description: "Read one file",
        input_schema: %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{"path" => %{"type" => "string"}},
          "required" => ["path"]
        },
        risk: risk,
        executor: {Executor, %{owner: self(), result: result}}
      )

    {:ok, registry} = Registry.new([definition])
    registry
  end

  defp context(allowed_risks, options \\ []) do
    {:ok, policy} =
      options
      |> Keyword.put(:allowed_risks, allowed_risks)
      |> Policy.new()

    {:ok, context} = Context.new(workspace: "/workspace/project", policy: policy)
    context
  end

  defp call(arguments, name \\ "read_file") do
    %{id: "call-1", name: name, arguments: arguments}
  end
end
