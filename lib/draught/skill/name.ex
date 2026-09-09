defmodule Draught.Skill.Name do
  @moduledoc """
  Validates portable skill names without allocating runtime atoms.

  Names use the shared `SKILL.md` kebab-case convention and are safe to use as
  one directory segment after validation.
  """

  @maximum_bytes 64
  @pattern ~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  @doc "Validates one bounded canonical skill name."
  @spec validate(term()) :: {:ok, String.t()} | {:error, :invalid_name}
  def validate(value) when is_binary(value) do
    valid =
      byte_size(value) > 0 and byte_size(value) <= @maximum_bytes and
        String.valid?(value) and Regex.match?(@pattern, value)

    result(valid, value)
  end

  def validate(_value) do
    {:error, :invalid_name}
  end

  defp result(true, value) do
    {:ok, value}
  end

  defp result(false, _value) do
    {:error, :invalid_name}
  end
end
