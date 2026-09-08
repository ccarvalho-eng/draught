defmodule Draught.CLI.UI.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.UI.Workspace

  test "shortens only paths inside the supplied user home" do
    assert Workspace.display("/Users/person/Projects/draught", "/Users/person") ==
             "~/Projects/draught"

    assert Workspace.display("/Users/person", "/Users/person") == "~"

    assert Workspace.display("/Users/person-two/project", "/Users/person") ==
             "/Users/person-two/project"
  end

  test "preserves absolute paths when the user home is unavailable or root" do
    assert Workspace.display("/workspace", nil) == "/workspace"
    assert Workspace.display("/workspace", "/") == "/workspace"
  end

  test "sanitizes path fields before displaying them" do
    assert Workspace.display("/Users/person/Project\nforged", "/Users/person") ==
             "~/Project forged"

    refute Workspace.display("/workspace\e[31mhidden", nil) =~ <<27>>
  end
end
