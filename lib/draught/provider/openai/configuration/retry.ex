defmodule Draught.Provider.OpenAI.Configuration.Retry do
  @moduledoc """
  Fixed, bounded retry settings for transient provider failures.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @maximum_attempts 4
  @maximum_delay_ms 5_000

  defstruct max_attempts: 3, fixed_delay_ms: 250

  @type t :: %__MODULE__{
          max_attempts: 1..4,
          fixed_delay_ms: 0..5_000
        }

  @doc "Builds retry settings within the provider's fixed safety bounds."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:max_attempts, :fixed_delay_ms]),
         {:ok, max_attempts} <- max_attempts(normalized),
         {:ok, fixed_delay_ms} <- fixed_delay_ms(normalized) do
      {:ok, %__MODULE__{max_attempts: max_attempts, fixed_delay_ms: fixed_delay_ms}}
    end
  end

  defp max_attempts(attributes) do
    value = Map.get(attributes, :max_attempts, 3)
    max_attempts_result(value)
  end

  defp max_attempts_result(value)
       when is_integer(value) and value >= 1 and value <= @maximum_attempts do
    {:ok, value}
  end

  defp max_attempts_result(_value) do
    Error.single(
      [:max_attempts],
      :invalid_value,
      "must be an integer from 1 to #{@maximum_attempts}"
    )
  end

  defp fixed_delay_ms(attributes) do
    value = Map.get(attributes, :fixed_delay_ms, 250)
    fixed_delay_ms_result(value)
  end

  defp fixed_delay_ms_result(value)
       when is_integer(value) and value >= 0 and value <= @maximum_delay_ms do
    {:ok, value}
  end

  defp fixed_delay_ms_result(_value) do
    Error.single(
      [:fixed_delay_ms],
      :invalid_value,
      "must be an integer from 0 to #{@maximum_delay_ms}"
    )
  end
end
