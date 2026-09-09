defmodule Draught.Skill.CatalogTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Catalog
  alias Draught.Skill.Metadata

  test "keeps the first definition and bounds the combined catalog" do
    entries =
      Enum.map(1..257, fn index ->
        %Metadata{
          description: "Skill #{index}",
          name: "skill-#{index}",
          origin: :workspace_draught
        }
      end)

    duplicate = %{hd(entries) | origin: :user_draught}
    catalog = Catalog.new([hd(entries), duplicate | tl(entries)], 2)

    assert Enum.count_until(catalog.entries, 257) == 256
    assert hd(catalog.entries).origin == :workspace_draught
    assert catalog.rejected == 3
  end
end
