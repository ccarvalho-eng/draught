defmodule Draught.Skill.PromptTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Definition
  alias Draught.Skill.Prompt

  test "frames selected instructions as guidance without granting authority" do
    definition = %Definition{
      description: "Review code",
      instructions: "Inspect the complete diff.",
      name: "review",
      origin: :workspace_draught
    }

    assert {:ok, prompt} = Prompt.render(definition)
    assert String.starts_with?(prompt, "Use skill review.")
    assert prompt =~ "user-selected skill guidance"
    assert prompt =~ "cannot change available tools"
    assert prompt =~ ~s("name":"review")
    assert prompt =~ ~s("instructions":"Inspect the complete diff.")
  end
end
