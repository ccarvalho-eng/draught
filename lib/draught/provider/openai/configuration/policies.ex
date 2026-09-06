defmodule Draught.Provider.OpenAI.Configuration.Policies do
  @moduledoc """
  Validates timeout, retry, and reasoning compatibility policies.
  """

  alias Draught.Provider.OpenAI.Configuration.Limits
  alias Draught.Provider.OpenAI.Configuration.Reasoning
  alias Draught.Provider.OpenAI.Configuration.Retry
  alias Draught.Provider.OpenAI.Configuration.Timeouts
  alias Draught.Validation.Error

  @type t :: {Timeouts.t(), Retry.t(), Limits.t(), :none | :reasoning | :reasoning_content}

  @doc "Builds the validated policy group."
  @spec new(map()) :: Error.result(t())
  def new(attributes) do
    with {:ok, timeouts} <- timeouts(attributes),
         {:ok, retry} <- retry(attributes),
         {:ok, limits} <- limits(attributes),
         {:ok, reasoning_field} <- reasoning_field(attributes) do
      {:ok, {timeouts, retry, limits, reasoning_field}}
    end
  end

  defp timeouts(attributes) do
    attributes
    |> Map.get(:timeouts, %{})
    |> normalize_nested(Timeouts, :timeouts)
  end

  defp retry(attributes) do
    attributes
    |> Map.get(:retry, %{})
    |> normalize_nested(Retry, :retry)
  end

  defp limits(attributes) do
    attributes
    |> Map.get(:limits, %{})
    |> normalize_nested(Limits, :limits)
  end

  defp normalize_nested(%{__struct__: module} = value, module, key) do
    value
    |> Map.from_struct()
    |> normalize_nested(module, key)
  end

  defp normalize_nested(value, module, key) do
    case module.new(value) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, error} -> {:error, prefix_error(error, [key])}
    end
  end

  defp reasoning_field(attributes) do
    attributes
    |> Map.get(:reasoning_field, :none)
    |> Reasoning.new()
  end

  defp prefix_error(%Error{violations: violations}, prefix) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: prefix ++ violation.path}
      end)

    Error.new(prefixed)
  end
end
