defmodule Draught.CLI.Interactive.Command.CatalogTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Command.Catalog

  test "keeps active and reserved command metadata in one catalog" do
    assert Enum.map(Catalog.active(), & &1.name) == [
             :help,
             :status,
             :doctor,
             :sessions,
             :resume,
             :new,
             :rename,
             :archive,
             :restore,
             :model,
             :exit
           ]

    assert Enum.map(Catalog.reserved(), & &1.name) == [
             :provider,
             :permissions,
             :web,
             :context,
             :compact,
             :diff,
             :review,
             :tools,
             :details
           ]

    assert %{argument: :optional, name: :model} = Catalog.find("model")
    assert %{argument: :required, name: :rename} = Catalog.find("rename")
    assert %{argument: :none, name: :help} = Catalog.find("help")
    assert Catalog.find("unknown") == nil
  end
end
