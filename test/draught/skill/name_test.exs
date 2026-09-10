defmodule Draught.Skill.NameTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Name

  test "shortens built-in Phoenix names for display" do
    assert Name.display("elixir-phoenix-review", :builtin) == "elixir-phx-review"

    assert Name.display("elixir-phoenix-review", :workspace_draught) ==
             "elixir-phoenix-review"
  end

  test "expands only valid shorthand prefixes" do
    assert Name.expand_shorthand("elixir-phx-review") ==
             {:ok, "elixir-phoenix-review"}

    assert Name.expand_shorthand("elixir-phoenix-review") == :error
    assert Name.expand_shorthand("elixir-phx-") == :error
  end

  test "accepts bounded kebab-case names" do
    assert Name.validate("ecto-migration-checker") == {:ok, "ecto-migration-checker"}
    assert Name.validate("skill-2") == {:ok, "skill-2"}
  end

  test "rejects names that are unsafe or not canonical" do
    for value <- ["", "Skill", "two--hyphens", "-leading", "trailing-", "../escape", :skill] do
      assert Name.validate(value) == {:error, :invalid_name}
    end

    too_long = String.duplicate("a", 65)
    assert Name.validate(too_long) == {:error, :invalid_name}
  end
end
