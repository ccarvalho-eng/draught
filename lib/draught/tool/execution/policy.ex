defmodule Draught.Tool.Execution.Policy do
  @moduledoc """
  Bounded execution settings and allowed tool risks.
  """

  alias Draught.Tool.Risk
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_timeout_ms 600_000
  @maximum_output_bytes 16 * 1024 * 1024

  defstruct allowed_risks: [:read], timeout_ms: 30_000, max_output_bytes: 1024 * 1024

  @type t :: %__MODULE__{
          allowed_risks: [Risk.t()],
          timeout_ms: pos_integer(),
          max_output_bytes: pos_integer()
        }

  @doc "Builds bounded tool execution policy."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:allowed_risks, :timeout_ms, :max_output_bytes]),
         {:ok, allowed_risks} <- allowed_risks(normalized),
         {:ok, timeout_ms} <- bounded(normalized, :timeout_ms, 30_000, @maximum_timeout_ms),
         {:ok, max_output_bytes} <-
           bounded(normalized, :max_output_bytes, 1024 * 1024, @maximum_output_bytes) do
      {:ok,
       %__MODULE__{
         allowed_risks: allowed_risks,
         timeout_ms: timeout_ms,
         max_output_bytes: max_output_bytes
       }}
    end
  end

  defp allowed_risks(attributes) do
    risks = Map.get(attributes, :allowed_risks, [:read])

    with true <- is_list(risks),
         {:ok, normalized} <- normalize_risks(risks),
         true <- length(Enum.uniq(normalized)) == length(normalized) do
      {:ok, normalized}
    else
      _invalid ->
        Error.single([:allowed_risks], :invalid_value, "must contain unique risk classes")
    end
  end

  defp normalize_risks(risks) do
    result =
      Enum.reduce_while(risks, {:ok, []}, fn risk, {:ok, normalized} ->
        case Risk.validate(risk, [:allowed_risks]) do
          {:ok, value} -> {:cont, {:ok, [value | normalized]}}
          {:error, %Error{}} = error -> {:halt, error}
        end
      end)

    reverse(result)
  end

  defp reverse({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse({:error, %Error{}} = result) do
    result
  end

  defp bounded(attributes, key, default, maximum) do
    value = Map.get(attributes, key, default)

    with {:ok, validated} <- Value.positive_integer(value, [key]),
         true <- validated <= maximum do
      {:ok, validated}
    else
      false -> Error.single([key], :invalid_value, "must not exceed #{maximum}")
      {:error, %Error{}} = result -> result
    end
  end
end
