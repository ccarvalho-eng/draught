defmodule Draught.Tool.RegistryTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry
  alias Draught.Tool.Specification
  alias Draught.Validation.Error

  defmodule Executor do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(call, context, owner) do
      send(owner, {:executed, call, context})
      {:ok, "done"}
    end
  end

  test "constructs definitions with portable metadata, risk, and an executor" do
    assert {:ok, definition} = definition("read_file", :read)
    assert definition.specification.name == "read_file"
    assert definition.risk == :read
    assert definition.executor == {Executor, self()}

    assert {:error, %Error{}} =
             Definition.new(
               name: "bad",
               description: "Bad executor",
               input_schema: schema(),
               risk: :unknown,
               executor: {String, nil}
             )
  end

  test "rejects structurally invalid parameter schemas" do
    assert {:error, %Error{}} =
             Specification.new(
               name: "bad_root",
               description: "Invalid root",
               input_schema: %{"type" => "string"}
             )

    assert {:error, %Error{}} =
             Specification.new(
               name: "bad_required",
               description: "Invalid required field",
               input_schema: %{
                 "type" => "object",
                 "properties" => %{"path" => %{"type" => "string"}},
                 "required" => ["missing"]
               }
             )
  end

  test "builds an explicit workspace and bounded policy context" do
    assert {:ok, policy} =
             Policy.new(allowed_risks: [:read, :write], timeout_ms: 500, max_output_bytes: 1_024)

    assert {:ok, context} = Context.new(workspace: "/workspace/project", policy: policy)
    assert context.workspace == "/workspace/project"
    assert context.policy.allowed_risks == [:read, :write]

    assert {:error, %Error{}} = Context.new(workspace: "relative/path", policy: policy)
    assert {:error, %Error{}} = Policy.new(allowed_risks: [:execute, :execute])
  end

  test "registers definitions immutably and preserves declaration order" do
    assert {:ok, read} = definition("read_file", :read)
    assert {:ok, write} = definition("write_file", :write)
    assert {:ok, registry} = Registry.new([read, write])

    assert Registry.names(registry) == ["read_file", "write_file"]
    assert Registry.specifications(registry) == [read.specification, write.specification]
    assert {:ok, ^write} = Registry.fetch(registry, "write_file")

    assert {:error, %Normalized{kind: :tool, code: "unknown_tool"}} =
             Registry.fetch(registry, "missing")

    assert {:error, %Error{}} = Registry.new([read, read])
  end

  defp definition(name, risk) do
    Definition.new(
      name: name,
      description: "Operate on one file",
      input_schema: schema(),
      risk: risk,
      executor: {Executor, self()}
    )
  end

  defp schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => %{"path" => %{"type" => "string"}},
      "required" => ["path"]
    }
  end
end
