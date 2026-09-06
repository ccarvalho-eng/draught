defmodule Draught.Provider.OpenAI.Configuration.Headers do
  @moduledoc """
  Normalizes custom HTTP headers while excluding framing and routing controls.
  """

  alias Draught.Validation.Error

  @reserved MapSet.new(["content-length", "content-type", "host"])
  @name_pattern ~r/^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/

  @doc "Builds a case-normalized map of validated custom headers."
  @spec new(term()) :: Error.result(%{optional(String.t()) => String.t()})
  def new(values) when is_map(values) do
    values
    |> Map.to_list()
    |> normalize()
  end

  def new(values) when is_list(values) do
    normalize(values)
  end

  def new(_values) do
    Error.single([:headers], :invalid_type, "must be a map or list of pairs")
  end

  defp normalize(values) do
    Enum.reduce_while(values, {:ok, %{}}, fn pair, {:ok, normalized} ->
      case normalize_header(pair, normalized) do
        {:ok, headers} -> {:cont, {:ok, headers}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp normalize_header({name, value}, normalized) do
    with {:ok, normalized_name} <- header_name(name),
         :ok <- available_header(normalized_name, normalized),
         {:ok, normalized_value} <- header_value(value) do
      {:ok, Map.put(normalized, normalized_name, normalized_value)}
    end
  end

  defp normalize_header(_pair, _normalized) do
    Error.single([:headers], :invalid_type, "must contain name and value pairs")
  end

  defp header_name(name) when is_binary(name) do
    normalized = String.downcase(name)
    valid = Regex.match?(@name_pattern, name) and not MapSet.member?(@reserved, normalized)
    header_name_result(valid, normalized)
  end

  defp header_name(_name) do
    Error.single([:headers], :invalid_type, "header names must be strings")
  end

  defp header_name_result(true, name) do
    {:ok, name}
  end

  defp header_name_result(false, _name) do
    Error.single([:headers], :invalid_value, "contains an invalid or reserved header name")
  end

  defp available_header(name, headers) when not is_map_key(headers, name) do
    :ok
  end

  defp available_header(_name, _headers) do
    Error.single([:headers], :duplicate_key, "contains a duplicate header name")
  end

  defp header_value(value) when is_binary(value) do
    valid = String.valid?(value) and not String.contains?(value, ["\r", "\n"])
    header_value_result(valid, value)
  end

  defp header_value(_value) do
    Error.single([:headers], :invalid_type, "header values must be strings")
  end

  defp header_value_result(true, value) do
    {:ok, value}
  end

  defp header_value_result(false, _value) do
    Error.single([:headers], :invalid_value, "contains an invalid header value")
  end
end
