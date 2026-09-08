defmodule Draught.Tool.Approval.Preview do
  @moduledoc """
  Builds bounded, lossless operation details for an approval display.

  Complete previews are ASCII JSON objects, limited to 16 KiB. Control and
  non-ASCII characters are escaped, not removed. Invalid or oversized operations
  return `:unavailable`, never partial content. `nil` denotes an absent preview.

  These values contain command arguments or replacement text and may include
  sensitive data. They are intended only for the trusted approval interface,
  not telemetry, journals, model messages, or general-purpose logging. Display
  consumers must not decode escapes into terminal control characters and must
  not treat missing or unavailable details as informed approval.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.JSON

  @maximum_bytes 16_384
  @printable_ascii ~r/\A[\x20-\x7E]+\z/

  @type t :: String.t() | :unavailable

  @doc "Encodes a bounded operation object or marks its complete preview unavailable."
  @spec build(term()) :: t()
  def build(operation) when is_map(operation) do
    with true <- :erlang.external_size(operation) <= @maximum_bytes,
         :ok <- JSON.validate_object(operation),
         {:ok, encoded} <- Jason.encode(operation, escape: :unicode_safe) do
      encoded
      |> String.replace(<<127>>, "\\u007f")
      |> bounded_result()
    else
      _invalid -> :unavailable
    end
  end

  def build(_operation) do
    :unavailable
  end

  @doc "Revalidates optional display metadata without reflecting invalid content."
  @spec validate(term()) :: Error.result(t() | nil)
  def validate(preview) when preview in [nil, :unavailable] do
    {:ok, preview}
  end

  def validate(preview) when is_binary(preview) and byte_size(preview) <= @maximum_bytes do
    with true <- Regex.match?(@printable_ascii, preview),
         {:ok, decoded} <- Jason.decode(preview),
         :ok <- JSON.validate_object(decoded) do
      {:ok, preview}
    else
      _invalid -> invalid()
    end
  end

  def validate(_preview) do
    invalid()
  end

  defp bounded_result(encoded) when byte_size(encoded) <= @maximum_bytes do
    encoded
  end

  defp bounded_result(_encoded) do
    :unavailable
  end

  defp invalid do
    Error.single([:preview], :invalid_value, "must be bounded ASCII JSON operation metadata")
  end
end
