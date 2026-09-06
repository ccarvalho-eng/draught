defmodule Draught.Provider.Ollama.Configuration.Requirements do
  @moduledoc """
  Validates capabilities required from a selected Ollama model.
  """

  alias Draught.Provider.Capabilities
  alias Draught.Validation.Error

  @features [:chat, :streaming, :tool_calls, :reasoning, :usage]
  @default [:chat, :streaming, :tool_calls]

  @doc "Builds a unique list of known capability requirements."
  @spec new(term()) :: Error.result([Capabilities.feature()])
  def new(value \\ @default)

  def new(value) when is_list(value) do
    valid = Enum.all?(value, &(&1 in @features)) and length(Enum.uniq(value)) == length(value)
    result(valid, value)
  end

  def new(_value) do
    invalid()
  end

  defp result(true, value) do
    {:ok, value}
  end

  defp result(false, _value) do
    invalid()
  end

  defp invalid do
    Error.single(
      [:required_capabilities],
      :invalid_value,
      "must contain unique chat, streaming, tool_calls, reasoning, or usage values"
    )
  end
end
