defmodule Draught.CLI.Task.Approval.PresentationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Presentation
  alias Draught.Tool.Approval.Request

  test "places a proposed replacement diff before complete JSON details" do
    request = request("replace_in_file", replacement_preview())

    assert {:ok, output} = Presentation.render(request, false)
    rendered = IO.iodata_to_binary(output)

    assert rendered =~ "Proposed diff:\n--- a/sample.txt"
    assert rendered =~ "\n- before\n+ after\n"
    assert rendered =~ "\nOperation (JSON):\n{\n"
    assert rendered =~ ~s("workspace": "/workspace")
    assert index(rendered, "Proposed diff:") < index(rendered, "Operation (JSON):")
  end

  test "uses JSON alone for other tools and fails when JSON cannot be rendered" do
    command = request("run_command", ~s({"arguments":["--version"],"executable":"git"}))
    assert {:ok, output} = Presentation.render(command, false)
    rendered = IO.iodata_to_binary(output)

    refute rendered =~ "Proposed diff"
    assert rendered =~ ~s("executable": "git")

    invalid = %{command | preview: "invalid"}
    assert {:error, :unavailable} = Presentation.render(invalid, false)
  end

  defp request(tool, preview) do
    {:ok, request} =
      Request.new(
        call_id: "call",
        tool: tool,
        target: "sample.txt",
        arguments_summary: "bounded summary",
        risk: :write,
        preview: preview
      )

    request
  end

  defp replacement_preview do
    Jason.encode!(%{
      "expected" => "before",
      "path" => "sample.txt",
      "replacement" => "after",
      "workspace" => "/workspace"
    })
  end

  defp index(value, pattern) do
    {position, _length} = :binary.match(value, pattern)
    position
  end
end
