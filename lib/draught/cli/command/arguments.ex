defmodule Draught.CLI.Command.Arguments do
  @moduledoc """
  Enforces argument count and byte limits before command parsing continues.
  """

  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.Specification

  @doc "Validates and separates arguments after the option terminator."
  @spec prepare(term()) :: {:ok, [String.t()], [String.t()]} | {:error, Error.t()}
  def prepare(arguments) when is_list(arguments) do
    limits = Specification.limits()

    with :ok <- argument_count(arguments, limits.arguments),
         :ok <- argument_values(arguments, limits.argument_bytes),
         :ok <- total_size(arguments, limits.total_argument_bytes) do
      split_literal(arguments, [])
    end
  end

  def prepare(_arguments) do
    error(:invalid_argument, "Arguments must be a list of UTF-8 strings")
  end

  defp argument_count(arguments, maximum) do
    count =
      arguments
      |> Enum.take(maximum + 1)
      |> Enum.count()

    at_most(count, maximum, :too_many_arguments, "Too many command arguments")
  end

  defp argument_values(arguments, maximum) do
    valid = Enum.all?(arguments, &valid_argument?(&1, maximum))
    valid_result(valid, :argument_too_large, "Command arguments must be bounded UTF-8 strings")
  end

  defp valid_argument?(argument, maximum) do
    is_binary(argument) and byte_size(argument) <= maximum and String.valid?(argument)
  end

  defp total_size(arguments, maximum) do
    size = Enum.sum_by(arguments, &byte_size/1)

    at_most(
      size,
      maximum,
      :argument_too_large,
      "Combined command arguments exceed the byte limit"
    )
  end

  defp split_literal([], parseable) do
    {:ok, Enum.reverse(parseable), []}
  end

  defp split_literal(["--" | literal], parseable) do
    {:ok, Enum.reverse(parseable), literal}
  end

  defp split_literal([argument | rest], parseable) do
    split_literal(rest, [argument | parseable])
  end

  defp at_most(value, maximum, _code, _message) when value <= maximum do
    :ok
  end

  defp at_most(_value, _maximum, code, message) do
    error(code, message)
  end

  defp valid_result(true, _code, _message) do
    :ok
  end

  defp valid_result(false, code, message) do
    error(code, message)
  end

  defp error(code, message) do
    {:error, Error.new(code, message)}
  end
end
