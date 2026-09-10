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

  test "renders commands as a compact shell-style line" do
    command =
      request(
        "run_command",
        Jason.encode!(%{
          "arguments" => ["test", "test/my file.exs", "it's"],
          "executable" => "mix"
        })
      )

    assert {:ok, output} = Presentation.render(command, false)
    rendered = IO.iodata_to_binary(output)

    refute rendered =~ "Proposed diff"
    refute rendered =~ "Operation (JSON)"
    assert rendered == ~s([command] mix test 'test/my file.exs' 'it'"'"'s'\n)
  end

  test "falls back to JSON for commands that cannot be represented safely" do
    command =
      request(
        "run_command",
        Jason.encode!(%{"arguments" => ["line\nbreak"], "executable" => "printf"})
      )

    assert {:ok, output} = Presentation.render(command, false)
    rendered = IO.iodata_to_binary(output)

    assert rendered =~ "Operation (JSON):\n"
    assert rendered =~ ~s("line\\nbreak")
    refute rendered =~ "line\nbreak"

    invalid = %{command | preview: "invalid"}
    assert {:error, :unavailable} = Presentation.render(invalid, false)

    non_object = %{command | preview: "[]"}
    assert {:error, :unavailable} = Presentation.render(non_object, false)
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
