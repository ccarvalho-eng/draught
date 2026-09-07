defmodule Draught.Tool.Builtin.RunCommand.Input do
  @moduledoc false

  @maximum_argument_bytes 4_096
  @maximum_arguments 128
  @maximum_executable_bytes 256
  @control_bytes ~r/[\x00-\x1F\x7F]/

  @enforce_keys [:arguments, :executable]
  defstruct [:arguments, :executable]

  @type t :: %__MODULE__{arguments: [String.t()], executable: String.t()}

  @doc "Builds bounded command input without interpreting it as shell text."
  @spec new(map()) :: {:ok, t()} | {:error, :invalid_input}
  def new(arguments) when is_map(arguments) do
    with {:ok, executable} <- executable(Map.get(arguments, "executable")),
         {:ok, command_arguments} <- command_arguments(Map.get(arguments, "arguments", [])) do
      {:ok, %__MODULE__{arguments: command_arguments, executable: executable}}
    end
  end

  defp executable(value)
       when is_binary(value) and byte_size(value) > 0 and
              byte_size(value) <= @maximum_executable_bytes do
    control_free(value)
  end

  defp executable(_value) do
    {:error, :invalid_input}
  end

  defp command_arguments(values) when is_list(values) do
    validate_arguments(values, @maximum_arguments, [])
  end

  defp command_arguments(_values) do
    {:error, :invalid_input}
  end

  defp argument(value) when is_binary(value) and byte_size(value) <= @maximum_argument_bytes do
    nul_free(value)
  end

  defp argument(_value) do
    {:error, :invalid_input}
  end

  defp control_free(value) do
    value
    |> then(&Regex.match?(@control_bytes, &1))
    |> control_free_result(value)
  end

  defp nul_free(value) do
    case :binary.match(value, <<0>>) do
      :nomatch -> {:ok, value}
      {_offset, _length} -> {:error, :invalid_input}
    end
  end

  defp validate_arguments([], _remaining, validated) do
    {:ok, Enum.reverse(validated)}
  end

  defp validate_arguments([_value | _rest], 0, _validated) do
    {:error, :invalid_input}
  end

  defp validate_arguments([value | rest], remaining, validated) do
    with {:ok, validated_argument} <- argument(value) do
      validate_arguments(rest, remaining - 1, [validated_argument | validated])
    end
  end

  defp control_free_result(true, _value) do
    {:error, :invalid_input}
  end

  defp control_free_result(false, value) do
    {:ok, value}
  end
end
