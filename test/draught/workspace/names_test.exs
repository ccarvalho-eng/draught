defmodule Draught.Workspace.NamesTest do
  use ExUnit.Case, async: true

  alias Draught.Session.Identifier
  alias Draught.Validation.Error
  alias Draught.Workspace.GeneratedFilename

  test "accepts portable session identifiers and generated filenames" do
    assert {:ok, "session-01"} = Identifier.new("session-01")
    assert {:ok, "journal_01.jsonl"} = GeneratedFilename.new("journal_01.jsonl")
  end

  test "rejects separators and traversal syntax" do
    for value <- [".", "..", "../session", "nested/session", "nested\\session"] do
      assert {:error, %Error{}} = Identifier.new(value)
      assert {:error, %Error{}} = GeneratedFilename.new(value)
    end
  end

  test "rejects empty, malformed, and oversized values" do
    oversized = String.duplicate("a", 129)

    for value <- ["", " leading", "colon:name", oversized] do
      assert {:error, %Error{}} = Identifier.new(value)
      assert {:error, %Error{}} = GeneratedFilename.new(value)
    end
  end
end
