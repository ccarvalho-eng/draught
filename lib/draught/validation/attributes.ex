defmodule Draught.Validation.Attributes do
  @moduledoc """
  Normalizes whitelisted atom and string attribute keys without creating atoms.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Violation

  @doc "Normalizes a map or keyword list against an explicit key whitelist."
  @spec normalize(term(), [atom()]) :: Error.result(map())
  def normalize(attributes, allowed_keys) do
    with {:ok, pairs} <- attribute_pairs(attributes) do
      normalize_pairs(pairs, allowed_keys)
    end
  end

  @doc "Fetches a required normalized attribute."
  @spec fetch_required(map(), atom()) :: Error.result(term())
  def fetch_required(attributes, key) do
    case Map.fetch(attributes, key) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        Error.single([key], :required, "is required")
    end
  end

  defp attribute_pairs(attributes) when is_map(attributes) do
    {:ok, Map.to_list(attributes)}
  end

  defp attribute_pairs(attributes) when is_list(attributes) do
    attributes
    |> Keyword.keyword?()
    |> keyword_result(attributes)
  end

  defp attribute_pairs(_attributes) do
    Error.single([], :invalid_type, "must be a map or keyword list")
  end

  defp normalize_pairs(pairs, allowed_keys) do
    {values, _seen, violations} =
      pairs
      |> Enum.sort_by(fn {key, _value} -> inspect(key) end)
      |> Enum.reduce({%{}, MapSet.new(), []}, fn {key, value}, accumulator ->
        normalize_pair(key, value, allowed_keys, accumulator)
      end)

    case violations do
      [] ->
        {:ok, values}

      [_violation | _rest] ->
        {:error, Error.new(violations)}
    end
  end

  defp normalize_pair(key, value, allowed_keys, {values, seen, violations}) do
    case canonical_key(key, allowed_keys) do
      nil ->
        violation = Violation.new([:unknown], :unknown_key, "attribute is not supported")
        {values, seen, [violation | violations]}

      canonical_key ->
        put_canonical_pair(canonical_key, value, values, seen, violations)
    end
  end

  defp canonical_key(key, allowed_keys) do
    Enum.find(allowed_keys, fn allowed_key ->
      key == allowed_key or key == Atom.to_string(allowed_key)
    end)
  end

  defp put_canonical_pair(key, value, values, seen, violations) do
    seen
    |> MapSet.member?(key)
    |> put_canonical_pair_result(key, value, values, seen, violations)
  end

  defp keyword_result(true, attributes) do
    {:ok, attributes}
  end

  defp keyword_result(false, _attributes) do
    Error.single([], :invalid_type, "must be a map or keyword list")
  end

  defp put_canonical_pair_result(true, key, _value, values, seen, violations) do
    violation = Violation.new([key], :duplicate_key, "was provided more than once")
    {values, seen, [violation | violations]}
  end

  defp put_canonical_pair_result(false, key, value, values, seen, violations) do
    {Map.put(values, key, value), MapSet.put(seen, key), violations}
  end
end
