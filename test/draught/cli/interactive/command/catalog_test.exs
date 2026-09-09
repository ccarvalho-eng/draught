defmodule Draught.CLI.Interactive.Command.CatalogTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Command.Catalog

  test "keeps active and reserved command metadata in one catalog" do
    assert Enum.map(Catalog.active(), & &1.name) == [
             :help,
             :clear,
             :status,
             :permissions,
             :doctor,
             :sessions,
             :resume,
             :new,
             :rename,
             :archive,
             :restore,
             :model,
             :tools,
             :skills,
             :skill,
             :exit
           ]

    assert Enum.map(Catalog.reserved(), & &1.name) == [
             :provider,
             :web,
             :context,
             :compact,
             :diff,
             :review,
             :details
           ]

    assert %{argument: :optional, name: :model} = Catalog.find("model")
    assert %{argument: :required, name: :rename} = Catalog.find("rename")
    assert %{argument: :required, name: :skill} = Catalog.find("skill")
    assert %{argument: :none, name: :clear} = Catalog.find("clear")
    assert %{argument: :none, name: :help} = Catalog.find("help")
    assert Catalog.find("unknown") == nil
  end
end
