defmodule Draught.CLI.Configuration.Decoder do
  @moduledoc false

  alias Draught.CLI.Configuration.Decoder.Normalizer
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Source

  @max_json_bytes 65_536

  @doc "Decodes and validates one bounded JSON configuration source."
  @spec decode(Source.kind(), binary()) :: Error.result(Source.t())
  def decode(kind, json) do
    with :ok <- Source.validate_kind(kind),
         :ok <- validate_input(kind, json),
         {:ok, decoded} <- decode_json(kind, json),
         {:ok, object} <- Normalizer.normalize(kind, decoded) do
      Source.from_map(kind, object)
    end
  end

  defp validate_input(kind, json) when is_binary(json) and byte_size(json) <= @max_json_bytes do
    json
    |> String.valid?()
    |> input_encoding_result(kind)
  end

  defp validate_input(kind, json) when is_binary(json) do
    Error.new(kind, [], :too_large, "exceeds the maximum JSON source size")
  end

  defp validate_input(kind, _json) do
    Error.new(kind, [], :invalid_type, "must be a JSON string")
  end

  defp decode_json(kind, json) do
    case Jason.decode(json, objects: :ordered_objects, strings: :copy) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _error} -> Error.new(kind, [], :invalid_json, "must contain valid JSON")
    end
  end

  defp input_encoding_result(true, _kind) do
    :ok
  end

  defp input_encoding_result(false, kind) do
    Error.new(kind, [], :invalid_json, "must contain valid UTF-8 JSON")
  end
end
