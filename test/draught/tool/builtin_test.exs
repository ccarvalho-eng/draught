defmodule Draught.Tool.BuiltinTest do
  use ExUnit.Case, async: true

  alias Draught.Tool.Builtin
  alias Draught.Tool.Registry
  alias Draught.Web.Capability

  defmodule SearchAdapter do
    @behaviour Draught.Web.Search.Adapter

    @impl Draught.Web.Search.Adapter
    def search(_query, _policy, _configuration) do
      {:ok, []}
    end
  end

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

  test "adds only explicitly enabled web operations" do
    web = Capability.new!(policy: [search: true], search: {SearchAdapter, nil})
    assert {:ok, registry} = Builtin.registry(web: web)

    assert Registry.names(registry) == [
             "read_file",
             "list_directory",
             "search_workspace",
             "replace_in_file",
             "run_command",
             "web_search"
           ]

    refute "web_fetch" in Registry.names(registry)
  end
end
