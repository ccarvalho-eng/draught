defmodule Draught.Skill.NameTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Name

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
