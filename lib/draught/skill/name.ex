defmodule Draught.Skill.Name do
  @moduledoc """
  Validates portable skill names without allocating runtime atoms.

  Names use the shared `SKILL.md` kebab-case convention and are safe to use as
  one directory segment after validation.
  """

  @maximum_bytes 64
  @pattern ~r/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  @builtin_prefix "elixir-phoenix-"
  @builtin_shorthand "elixir-phx-"

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

  @doc "Returns the compact public name used for a built-in skill."
  @spec display(String.t(), atom()) :: String.t()
  def display(@builtin_prefix <> suffix, :builtin) do
    @builtin_shorthand <> suffix
  end

  def display(name, _origin) do
    name
  end

  @doc "Expands a compact built-in reference to its canonical repository name."
  @spec expand_shorthand(String.t()) :: {:ok, String.t()} | :error
  def expand_shorthand(@builtin_shorthand <> suffix) when suffix != "" do
    {:ok, @builtin_prefix <> suffix}
  end

  def expand_shorthand(_name) do
    :error
  end

  defp result(true, value) do
    {:ok, value}
  end

  defp result(false, _value) do
    {:error, :invalid_name}
  end
end
