defmodule Draught.Provider.Usage do
  @moduledoc """
  Token usage normalized across providers.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:input_tokens, :output_tokens, :total_tokens, :cached_tokens, :reasoning_tokens]
  defstruct [:input_tokens, :output_tokens, :total_tokens, :cached_tokens, :reasoning_tokens]

  @type t :: %__MODULE__{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          total_tokens: non_neg_integer(),
          cached_tokens: non_neg_integer(),
          reasoning_tokens: non_neg_integer()
        }

  @doc "Builds usage and verifies the relationships between token counts."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [
             :input_tokens,
             :output_tokens,
             :total_tokens,
             :cached_tokens,
             :reasoning_tokens
           ]) do
      normalize_usage(normalized)
    end
  end

  defp normalize_usage(attributes) do
    with {:ok, input_tokens, output_tokens} <- base_counts(attributes),
         {:ok, details} <- detail_counts(attributes, input_tokens, output_tokens) do
      {:ok,
       %__MODULE__{
         input_tokens: input_tokens,
         output_tokens: output_tokens,
         total_tokens: details.total_tokens,
         cached_tokens: details.cached_tokens,
         reasoning_tokens: details.reasoning_tokens
       }}
    end
  end

  defp base_counts(attributes) do
    with {:ok, input_tokens} <- required_count(attributes, :input_tokens),
         {:ok, output_tokens} <- required_count(attributes, :output_tokens) do
      {:ok, input_tokens, output_tokens}
    end
  end

  defp detail_counts(attributes, input_tokens, output_tokens) do
    with {:ok, total_tokens} <- total_tokens(attributes, input_tokens, output_tokens),
         {:ok, cached_tokens} <- optional_count(attributes, :cached_tokens),
         {:ok, reasoning_tokens} <- optional_count(attributes, :reasoning_tokens),
         :ok <- validate_subtotals(input_tokens, output_tokens, cached_tokens, reasoning_tokens) do
      {:ok,
       %{
         total_tokens: total_tokens,
         cached_tokens: cached_tokens,
         reasoning_tokens: reasoning_tokens
       }}
    end
  end

  defp required_count(attributes, key) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      Value.non_negative_integer(value, [key])
    end
  end

  defp optional_count(attributes, key) do
    case Map.get(attributes, key, 0) do
      value -> Value.non_negative_integer(value, [key])
    end
  end

  defp total_tokens(attributes, input_tokens, output_tokens) do
    expected = input_tokens + output_tokens

    case Map.fetch(attributes, :total_tokens) do
      {:ok, ^expected} -> {:ok, expected}
      {:ok, _value} -> total_mismatch()
      :error -> {:ok, expected}
    end
  end

  defp total_mismatch do
    Error.single(
      [:total_tokens],
      :invalid_relationship,
      "must equal input tokens plus output tokens"
    )
  end

  defp validate_subtotals(input_tokens, output_tokens, cached_tokens, reasoning_tokens) do
    cond do
      cached_tokens > input_tokens ->
        Error.single(
          [:cached_tokens],
          :invalid_relationship,
          "must not exceed input tokens"
        )

      reasoning_tokens > output_tokens ->
        Error.single(
          [:reasoning_tokens],
          :invalid_relationship,
          "must not exceed output tokens"
        )

      true ->
        :ok
    end
  end
end
