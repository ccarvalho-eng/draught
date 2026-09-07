defmodule Draught.CLI.Configuration.Value do
  @moduledoc """
  Normalizes bounded scalar configuration values from files, environment variables, and flags.
  """

  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Source

  @forbidden_codepoints [
                          Enum.to_list(0x00..0x1F),
                          Enum.to_list(0x7F..0x9F),
                          Enum.to_list(0x202A..0x202E),
                          Enum.to_list(0x200B..0x200F),
                          Enum.to_list(0x2060..0x206F),
                          [0x061C, 0xFEFF]
                        ]
                        |> Enum.concat()
                        |> MapSet.new()

  @doc "Validates bounded display-safe text without retaining rejected input."
  @spec text(term(), Source.kind(), [atom()], pos_integer()) :: Error.result(String.t())
  def text(value, source, path, maximum_bytes) when is_binary(value) do
    valid =
      byte_size(value) > 0 and byte_size(value) <= maximum_bytes and String.valid?(value) and
        safe_codepoints?(value)

    text_result(valid, value, source, path)
  end

  def text(_value, source, path, _maximum_bytes) do
    Error.new(source, path, :invalid_type, "must be a string")
  end

  @doc "Validates a configuration boolean."
  @spec boolean(term(), Source.kind(), [atom()]) :: Error.result(boolean())
  def boolean(value, _source, _path) when is_boolean(value) do
    {:ok, value}
  end

  def boolean(_value, source, path) do
    Error.new(source, path, :invalid_type, "must be a boolean")
  end

  @doc "Maps a risk string to the closed risk policy."
  @spec risk(term(), Source.kind()) :: Error.result(:deny | :ask | :allow)
  def risk("deny", _source) do
    {:ok, :deny}
  end

  def risk("ask", _source) do
    {:ok, :ask}
  end

  def risk("allow", _source) do
    {:ok, :allow}
  end

  def risk(_value, source) do
    Error.new(source, [:risk], :invalid_value, "must be deny, ask, or allow")
  end

  @doc "Maps a provider string to the closed built-in provider set."
  @spec provider(term(), Source.kind()) :: Error.result(:ollama | :openai_compatible)
  def provider("ollama", _source) do
    {:ok, :ollama}
  end

  def provider("openai-compatible", _source) do
    {:ok, :openai_compatible}
  end

  def provider(_value, source) do
    Error.new(source, [:profiles, :provider], :invalid_value, "is not a supported provider")
  end

  defp safe_codepoints?(value) do
    value
    |> String.to_charlist()
    |> Enum.all?(fn codepoint -> not MapSet.member?(@forbidden_codepoints, codepoint) end)
  end

  defp text_result(true, value, _source, _path) do
    {:ok, value}
  end

  defp text_result(false, _value, source, path) do
    Error.new(source, path, :invalid_value, "must be bounded display-safe UTF-8")
  end
end
