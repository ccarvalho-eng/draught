defmodule Draught.Tool.Approval.PreviewTest do
  use ExUnit.Case, async: true

  alias Draught.Tool.Approval
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Tool.Approval.Preview
  alias Draught.Tool.Approval.Request
  alias Draught.Validation.Error

  test "encodes exact argument boundaries and escapes display controls losslessly" do
    arguments = ["", "two words", "$(touch file)", "\n\e[2J\r\t\"\\", <<127>>, "é🙂\u202E"]
    operation = %{"executable" => "echo", "arguments" => arguments, "workspace" => "/workspace"}

    preview = Preview.build(operation)

    assert is_binary(preview)
    assert Jason.decode!(preview) == operation
    assert Regex.match?(~r/\A[\x20-\x7E]+\z/, preview)
    assert {:ok, ^preview} = Preview.validate(preview)
  end

  test "preserves replacement text including newlines and empty replacement" do
    operation = %{
      "path" => "lib/example.ex",
      "expected" => "before\nafter\n",
      "replacement" => ""
    }

    preview = Preview.build(operation)

    assert Jason.decode!(preview) == operation
  end

  test "marks oversized input and expanded output unavailable without partial content" do
    assert Preview.build(%{"text" => String.duplicate("x", 16_385)}) == :unavailable
    assert Preview.build(%{"text" => String.duplicate("\n", 9_000)}) == :unavailable
    assert Preview.build(%{"text" => String.duplicate("x", 16_000)}) != :unavailable
  end

  test "invalid operation data is unavailable without raising or reflecting values" do
    for operation <- [nil, [], %{"text" => <<255>>}, %{"value" => self()}] do
      assert Preview.build(operation) == :unavailable
    end
  end

  test "reconstruction rejects unsafe, malformed, and unbounded display values" do
    for preview <- [
          "",
          "[]",
          "null",
          "{}\n",
          "{\"x\":\"\e\"}",
          "{\"x\":\"é\"}",
          String.duplicate("x", 16_385),
          %{},
          true
        ] do
      assert {:error, %Error{}} = Preview.validate(preview)
    end

    assert {:ok, nil} = Preview.validate(nil)
    assert {:ok, :unavailable} = Preview.validate(:unavailable)
  end

  test "approval requests retain an optional validated preview independently of the summary" do
    attributes = %{
      call_id: "call-1",
      tool: "run_command",
      target: "echo",
      arguments_summary: "1 arguments; isolated environment",
      risk: :execute
    }

    assert {:ok, %{preview: nil}} = Request.new(attributes)
    preview = Preview.build(%{"executable" => "echo", "arguments" => ["value"]})

    assert {:ok, request} =
             attributes
             |> Map.put(:preview, preview)
             |> Request.new()

    assert request.preview == preview
    assert request.arguments_summary == attributes.arguments_summary

    assert {:ok, %{preview: :unavailable}} =
             attributes
             |> Map.put(:preview, :unavailable)
             |> Request.new()

    assert {:error, %Error{}} =
             attributes
             |> Map.put(:preview, "unsafe\n")
             |> Request.new()

    forged = %{request | preview: "unsafe\n"}
    assert {:error, %{code: "invalid_approval_request"}} = Approval.decide({Default, nil}, forged)
  end
end
