defmodule Draught.CLI.Interactive.Model.Reference do
  @moduledoc """
  Resolves model references against one bounded compatible-model snapshot.

  Exact names take precedence over one-based positions so numeric model names
  remain addressable without ambiguity.
  """

  @doc "Resolves an exact model name or one-based position."
  @spec resolve(String.t(), [String.t()]) :: {:ok, String.t()} | {:error, :not_found}
  def resolve(reference, models) when is_binary(reference) and is_list(models) do
    case Enum.find(models, &(&1 == reference)) do
      nil -> resolve_position(reference, models)
      model -> {:ok, model}
    end
  end

  @doc "Resolves only an exact model name."
  @spec exact(String.t(), [String.t()]) :: {:ok, String.t()} | {:error, :not_found}
  def exact(reference, models) when is_binary(reference) and is_list(models) do
    case Enum.find(models, &(&1 == reference)) do
      nil -> {:error, :not_found}
      model -> {:ok, model}
    end
  end

  defp resolve_position(reference, models) do
    case Integer.parse(reference) do
      {position, ""} when position > 0 -> fetch_position(models, position)
      _result -> {:error, :not_found}
    end
  end

  defp fetch_position(models, position) do
    case Enum.fetch(models, position - 1) do
      {:ok, model} -> {:ok, model}
      :error -> {:error, :not_found}
    end
  end
end
