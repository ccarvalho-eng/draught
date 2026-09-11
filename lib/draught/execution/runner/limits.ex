defmodule Draught.Execution.Runner.Limits do
  @moduledoc """
  Bounded iteration, time, and output limits for one agent run.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_iterations 100
  @maximum_output_bytes 16 * 1024 * 1024
  @maximum_timeout_ms 600_000

  defstruct max_iterations: 100,
            max_output_bytes: 1024 * 1024,
            provider_timeout_ms: 120_000,
            tool_timeout_ms: 30_000

  @type t :: %__MODULE__{
          max_iterations: pos_integer(),
          max_output_bytes: pos_integer(),
          provider_timeout_ms: pos_integer(),
          tool_timeout_ms: pos_integer()
        }

  @doc "Builds validated runner limits."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [
             :max_iterations,
             :max_output_bytes,
             :provider_timeout_ms,
             :tool_timeout_ms
           ]),
         {:ok, max_iterations} <-
           bounded(normalized, :max_iterations, 12, @maximum_iterations),
         {:ok, max_output_bytes} <-
           bounded(normalized, :max_output_bytes, 1024 * 1024, @maximum_output_bytes),
         {:ok, provider_timeout_ms} <-
           bounded(normalized, :provider_timeout_ms, 120_000, @maximum_timeout_ms),
         {:ok, tool_timeout_ms} <-
           bounded(normalized, :tool_timeout_ms, 30_000, @maximum_timeout_ms) do
      {:ok,
       %__MODULE__{
         max_iterations: max_iterations,
         max_output_bytes: max_output_bytes,
         provider_timeout_ms: provider_timeout_ms,
         tool_timeout_ms: tool_timeout_ms
       }}
    end
  end

  defp bounded(attributes, key, default, maximum) do
    value = Map.get(attributes, key, default)
    Value.positive_integer_at_most(value, maximum, [key])
  end
end
