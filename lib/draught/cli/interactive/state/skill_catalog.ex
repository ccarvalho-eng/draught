defmodule Draught.CLI.Interactive.State.SkillCatalog do
  @moduledoc """
  Validates the bounded skill names retained for effect-free completion.

  Instruction bodies, descriptions, origins, and filesystem paths never enter
  interactive completion state.
  """

  alias Draught.Skill.Name

  @maximum_entries 256

  @doc "Validates unique canonical skill names within the completion bound."
  @spec validate(term()) :: {:ok, [String.t()]} | {:error, :invalid_skill_catalog}
  def validate(names) when is_list(names) do
    bounded = Enum.count_until(names, @maximum_entries + 1) <= @maximum_entries
    unique = Enum.uniq(names) == names
    valid = Enum.all?(names, &match?({:ok, _name}, Name.validate(&1)))
    result(bounded and unique and valid, names)
  end

  def validate(_names) do
    {:error, :invalid_skill_catalog}
  end

  defp result(true, names) do
    {:ok, names}
  end

  defp result(false, _names) do
    {:error, :invalid_skill_catalog}
  end
end
