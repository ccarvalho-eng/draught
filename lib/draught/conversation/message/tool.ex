defmodule Draught.Conversation.Message.Tool do
  @moduledoc """
  A conversation message containing exactly one tool result.
  """

  alias Draught.Tool.Result
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:result]
  defstruct [:result]

  @type t :: %__MODULE__{result: Result.t()}

  @doc "Builds a validated tool-result message."
  @spec new(Result.t() | map() | keyword()) :: Error.result(t())
  def new(%Result{} = result) do
    normalized_result =
      result
      |> Map.from_struct()
      |> Result.new()

    with {:ok, normalized} <- normalized_result do
      {:ok, %__MODULE__{result: normalized}}
    end
  end

  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:result]),
         {:ok, raw_result} <- Attributes.fetch_required(normalized, :result),
         {:ok, result} <- normalize_result(raw_result) do
      {:ok, %__MODULE__{result: result}}
    end
  end

  defp normalize_result(%Result{} = result) do
    result
    |> Map.from_struct()
    |> Result.new()
  end

  defp normalize_result(result) when is_map(result) or is_list(result) do
    Result.new(result)
  end

  defp normalize_result(_result) do
    Error.single([:result], :invalid_type, "must be a tool result")
  end
end
