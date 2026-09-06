defmodule Draught.Tool.ContractsTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Name
  alias Draught.Tool.Result
  alias Draught.Tool.Specification
  alias Draught.Validation.Error

  test "validates portable tool names" do
    assert {:ok, "read_file-2"} = Name.validate("read_file-2")
    assert {:error, %Error{}} = Name.validate("not portable!")

    invalid_name =
      "a"
      |> String.duplicate(65)
      |> Name.validate()

    assert {:error, %Error{}} = invalid_name
  end

  test "constructs tool calls with JSON arguments" do
    assert {:ok, call} = Call.new(id: "call-1", name: "read_file")
    assert call.arguments == %{}

    assert {:ok, nested} =
             Call.new(id: "call-2", name: "write_file", arguments: %{"lines" => ["one"]})

    assert nested.arguments == %{"lines" => ["one"]}
    assert {:error, %Error{}} = Call.new(id: "call-3", name: "bad", arguments: %{path: true})
  end

  test "constructs portable tool specifications" do
    assert {:ok, specification} =
             Specification.new(
               name: "read_file",
               description: "Read one file",
               input_schema: %{"type" => "object"}
             )

    assert specification.name == "read_file"

    assert {:error, %Error{}} =
             Specification.new(name: "read_file", description: "Read", input_schema: [])
  end

  test "enforces tool-result status and error relationships" do
    assert {:ok, success} =
             Result.new(call_id: "call-1", name: "read_file", content: "contents")

    assert success.status == :success
    assert success.error == nil

    assert {:ok, timeout} =
             Normalized.new(:timeout, "tool_timeout", "tool timed out", retryable: true)

    assert {:ok, failed} =
             Result.new(
               call_id: "call-1",
               name: "read_file",
               content: "",
               status: :error,
               error: timeout
             )

    assert failed.error == timeout

    assert {:error, %Error{}} =
             Result.new(call_id: "call-1", name: "read_file", content: "", status: :error)

    assert {:error, %Error{}} =
             Result.new(
               call_id: "call-1",
               name: "read_file",
               content: "",
               error: timeout
             )

    assert {:ok, transport} =
             Normalized.new(:transport, "network", "network failed", retryable: true)

    assert {:error, %Error{}} =
             Result.new(
               call_id: "call-1",
               name: "read_file",
               content: "",
               status: :error,
               error: transport
             )
  end
end
