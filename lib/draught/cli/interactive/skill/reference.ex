defmodule Draught.CLI.Interactive.Skill.Reference do
  @moduledoc """
  Resolves canonical one-based skill positions against a bounded catalog.

  Exact skill names are handled before this module is called, so numeric names
  retain precedence over positional selection.
  """

  alias Draught.Skill.Catalog
  alias Draught.Skill.Metadata

  @doc "Parses one canonical positive integer skill position."
  @spec position(term()) :: {:ok, pos_integer()} | {:error, :not_found}
  def position(reference) when is_binary(reference) do
    case Integer.parse(reference) do
      {position, ""} when position > 0 ->
        canonical_position(reference, position)

      _invalid ->
        {:error, :not_found}
    end
  end

  def position(_reference) do
    {:error, :not_found}
  end

  @doc "Resolves a validated one-based position against catalog metadata or retained names."
  @spec name(pos_integer(), Catalog.t()) :: {:ok, String.t()} | {:error, :not_found}
  def name(position, %Catalog{entries: entries}) when is_integer(position) and position > 0 do
    case Enum.fetch(entries, position - 1) do
      {:ok, %Metadata{name: name}} -> {:ok, name}
      :error -> {:error, :not_found}
    end
  end

  @spec name(pos_integer(), [String.t()]) :: {:ok, String.t()} | {:error, :not_found}
  def name(position, names) when is_integer(position) and position > 0 and is_list(names) do
    case Enum.fetch(names, position - 1) do
      {:ok, name} when is_binary(name) -> {:ok, name}
      _invalid -> {:error, :not_found}
    end
  end

  defp canonical_position(reference, position) do
    canonical_position_result(reference, Integer.to_string(position), position)
  end

  defp canonical_position_result(reference, reference, position) do
    {:ok, position}
  end

  defp canonical_position_result(_reference, _canonical, _position) do
    {:error, :not_found}
  end
end
