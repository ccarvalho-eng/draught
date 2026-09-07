defmodule Draught.Tool.BuiltinTest do
  use ExUnit.Case, async: true

  alias Draught.Tool.Builtin
  alias Draught.Tool.Registry

  test "builds the standard registry in stable order" do
    assert {:ok, registry} = Builtin.registry()

    assert Registry.names(registry) == [
             "read_file",
             "list_directory",
             "search_workspace",
             "replace_in_file",
             "run_command"
           ]

    risks = Enum.map(registry.definitions, fn {_name, definition} -> definition.risk end)
    assert Enum.sort(risks) == [:execute, :read, :read, :read, :write]
  end
end
