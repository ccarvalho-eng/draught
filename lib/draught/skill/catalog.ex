defmodule Draught.Skill.Catalog do
  @moduledoc """
  Holds a deterministic bounded projection of discoverable skill metadata.
  """

  alias Draught.Skill.Metadata

  @maximum_entries 256

  @enforce_keys [:entries, :rejected]
  defstruct [:entries, :rejected]

  @type t :: %__MODULE__{entries: [Metadata.t()], rejected: non_neg_integer()}

  @doc "Builds a catalog from precedence-ordered metadata and a rejection count."
  @spec new([Metadata.t()], non_neg_integer()) :: t()
  def new(entries, rejected) when is_list(entries) and is_integer(rejected) and rejected >= 0 do
    {bounded, overflow} =
      entries
      |> Enum.uniq_by(& &1.name)
      |> Enum.split(@maximum_entries)

    %__MODULE__{entries: bounded, rejected: rejected + length(overflow)}
  end
end
