defmodule Draught.Conversation.Attachment.PortableValue do
  @moduledoc """
  Applies shared type, byte-size, and shape checks to portable string values.

  Callers supply the field path, size boundary, accepted pattern, and validation
  message so errors retain their domain-specific location.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @doc "Validates a bounded string against the supplied portable-value pattern."
  @spec validate(term(), [term()], pos_integer(), Regex.t(), String.t()) ::
          Error.result(String.t())
  def validate(value, path, maximum_bytes, pattern, shape_message) do
    with {:ok, value} <- Value.string(value, path),
         :ok <- validate_size(value, path, maximum_bytes),
         :ok <- validate_shape(value, path, pattern, shape_message) do
      {:ok, value}
    end
  end

  defp validate_size(value, _path, maximum_bytes) when byte_size(value) <= maximum_bytes do
    :ok
  end

  defp validate_size(_value, path, maximum_bytes) do
    Error.single(path, :too_large, "must not exceed #{maximum_bytes} bytes")
  end

  defp validate_shape(value, path, pattern, shape_message) do
    pattern
    |> Regex.match?(value)
    |> shape_result(path, shape_message)
  end

  defp shape_result(true, _path, _shape_message) do
    :ok
  end

  defp shape_result(false, path, shape_message) do
    Error.single(path, :invalid_value, shape_message)
  end
end
