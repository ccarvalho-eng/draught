defmodule Draught.Conversation.Document.Usage do
  @moduledoc false

  alias Draught.Provider.Usage
  alias Draught.Validation.Error

  @doc "Normalizes optional provider usage and prefixes validation failures."
  @spec normalize(term()) :: Error.result(Usage.t() | nil)
  def normalize(nil) do
    {:ok, nil}
  end

  def normalize(%Usage{} = usage) do
    usage
    |> Map.from_struct()
    |> Usage.new()
    |> prefix_error()
  end

  def normalize(usage) when is_map(usage) or is_list(usage) do
    usage
    |> Usage.new()
    |> prefix_error()
  end

  def normalize(_usage) do
    Error.single([:usage], :invalid_type, "must be token usage")
  end

  defp prefix_error({:ok, %Usage{}} = result) do
    result
  end

  defp prefix_error({:error, %Error{} = error}) do
    violations =
      Enum.map(error.violations, fn violation ->
        %{violation | path: [:usage | violation.path]}
      end)

    {:error, Error.new(violations)}
  end
end
