defmodule Draught.Workspace.Path.LexicalTest do
  use ExUnit.Case, async: true

  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Boundary
  alias Draught.Workspace.Path.Lexical

  test "resolves a nested relative path against an absolute workspace" do
    assert {:ok, "/workspace/project/lib/example.ex"} =
             Lexical.resolve("/workspace/project", "lib/example.ex")

    assert {:ok, "/workspace/project/README.md"} =
             Lexical.resolve("/workspace/project/.", "README.md")
  end

  test "rejects relative workspaces and absolute target paths" do
    assert {:error, %Error{}} = Lexical.resolve("workspace/project", "README.md")
    assert {:error, %Error{}} = Lexical.resolve("/workspace/project", "/etc/passwd")
    assert {:error, %Error{}} = Lexical.resolve("/workspace/project", "C:\\Windows\\system.ini")
    assert {:error, %Error{}} = Lexical.resolve("/workspace/project", "C:/Windows/system.ini")
    assert {:error, %Error{}} = Lexical.resolve("/workspace/project", "C:system.ini")
  end

  test "rejects traversal and ambiguous separators" do
    for path <- ["../outside", "lib/../../outside", "lib/../README.md", "..\\outside"] do
      assert {:error, %Error{}} = Lexical.resolve("/workspace/project", path)
    end
  end

  test "compares containment by components rather than string prefix" do
    assert Boundary.within?("/workspace/project", "/workspace/project/lib/example.ex")
    assert Boundary.within?("/workspace/project", "/workspace/project")
    refute Boundary.within?("/workspace/project", "/workspace/project-sibling/file")
    refute Boundary.within?("/workspace/project", "/workspace")
  end
end
