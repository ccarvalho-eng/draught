defmodule Draught.Provider.Capabilities do
  @moduledoc """
  Explicit provider features used for capability negotiation.
  """

  alias Draught.Error.Normalized
  alias Draught.Validation
  alias Draught.Validation.Attributes
  alias Draught.Validation.Value

  @features [:chat, :streaming, :tool_calls, :reasoning, :usage]
  @attributes [:chat, :streaming, :tool_calls, :reasoning, :usage, :context_window]

  defstruct chat: false,
            streaming: false,
            tool_calls: false,
            reasoning: false,
            usage: false,
            context_window: nil

  @type feature :: :chat | :streaming | :tool_calls | :reasoning | :usage
  @type t :: %__MODULE__{
          chat: boolean(),
          streaming: boolean(),
          tool_calls: boolean(),
          reasoning: boolean(),
          usage: boolean(),
          context_window: pos_integer() | nil
        }

  @doc "Builds an explicit capability set."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, @attributes),
         {:ok, features} <- feature_values(normalized),
         {:ok, context_window} <- context_window(normalized) do
      {:ok,
       %__MODULE__{
         chat: features.chat,
         streaming: features.streaming,
         tool_calls: features.tool_calls,
         reasoning: features.reasoning,
         usage: features.usage,
         context_window: context_window
       }}
    end
  end

  @doc "Returns whether a provider advertises a known feature."
  @spec supports?(t(), feature()) :: boolean()
  def supports?(%__MODULE__{} = capabilities, feature) when feature in @features do
    Map.fetch!(capabilities, feature)
  end

  @doc "Requires a feature or returns a canonical capability error."
  @spec require(t(), feature()) :: :ok | {:error, Normalized.t()}
  def require(%__MODULE__{} = capabilities, feature) when feature in @features do
    capabilities
    |> supports?(feature)
    |> requirement_result(feature)
  end

  defp boolean(attributes, key) do
    attributes
    |> Map.get(key, false)
    |> Value.boolean([key])
  end

  defp feature_values(attributes) do
    Enum.reduce_while(@features, {:ok, %{}}, fn feature, {:ok, features} ->
      case boolean(attributes, feature) do
        {:ok, value} -> {:cont, {:ok, Map.put(features, feature, value)}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp context_window(attributes) do
    case Map.fetch(attributes, :context_window) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> Value.positive_integer(value, [:context_window])
      :error -> {:ok, nil}
    end
  end

  defp requirement_result(true, _feature) do
    :ok
  end

  defp requirement_result(false, feature) do
    {:ok, error} =
      Normalized.new(
        :capability,
        "unsupported_capability",
        "provider does not support #{feature}",
        retryable: false
      )

    {:error, error}
  end
end
