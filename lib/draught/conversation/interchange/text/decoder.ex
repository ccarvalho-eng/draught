defmodule Draught.Conversation.Interchange.Text.Decoder do
  @moduledoc false

  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Text.Decoder.Extension
  alias Draught.Validation.Error

  @extension_marker "@@@draught.json"
  @extension_prefix @extension_marker <> "\n"
  @ambiguous_markers [
    "\n" <> @extension_marker <> "\n",
    "\n" <> @extension_marker <> "\r\n"
  ]

  @doc "Decodes one bounded text input."
  @spec decode(term(), pos_integer()) :: Error.result(Document.t())
  def decode(input, maximum_bytes) when is_binary(input) do
    with :ok <- validate_size(input, maximum_bytes),
         :ok <- validate_utf8(input) do
      decode_valid_input(input)
    end
  end

  def decode(_input, _maximum_bytes) do
    Error.single([], :invalid_type, "must be UTF-8 text")
  end

  defp decode_valid_input(<<@extension_prefix, rest::binary>>) do
    Extension.decode(rest)
  end

  defp decode_valid_input(input) do
    input
    |> reserved_marker_line?()
    |> decode_markdown(input)
  end

  defp reserved_marker_line?(input) do
    leading_marker?(input) or
      trailing_marker?(input) or
      :binary.match(input, @ambiguous_markers) != :nomatch
  end

  defp validate_size(input, maximum_bytes) when byte_size(input) <= maximum_bytes do
    :ok
  end

  defp validate_size(_input, maximum_bytes) do
    Error.single([], :too_large, "artifact must not exceed #{maximum_bytes} bytes")
  end

  defp validate_utf8(input) do
    input
    |> String.valid?()
    |> utf8_result()
  end

  defp decode_markdown(true, _input) do
    Error.single([], :invalid_format, "contains an ambiguous Draught extension marker")
  end

  defp decode_markdown(false, input) do
    Document.new(messages: [%{"role" => "user", "content" => input}])
  end

  defp utf8_result(true) do
    :ok
  end

  defp utf8_result(false) do
    Error.single([], :invalid_format, "must contain valid UTF-8 text")
  end

  defp leading_marker?(input) do
    input == @extension_marker or
      String.starts_with?(input, @extension_marker <> "\r\n")
  end

  defp trailing_marker?(input) do
    String.ends_with?(input, "\n" <> @extension_marker) or
      String.ends_with?(input, "\n" <> @extension_marker <> "\r")
  end
end
