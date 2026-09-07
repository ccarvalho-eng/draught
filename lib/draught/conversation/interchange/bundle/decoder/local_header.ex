defmodule Draught.Conversation.Interchange.Bundle.Decoder.LocalHeader do
  @moduledoc """
  Cross-checks local ZIP headers against validated central-directory metadata.

  It also returns each complete local-entry byte range so the caller can reject
  overlaps before extraction.
  """

  alias Draught.Conversation.Interchange.Bundle.Decoder.Header
  alias Draught.Validation.Error

  @signature <<0x04034B50::little-32>>
  @fixed_size 30

  @doc "Cross-checks a local ZIP header and returns its complete byte range."
  @spec validate(binary(), non_neg_integer(), Header.t(), non_neg_integer()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, Error.t()}
  def validate(archive, directory_offset, header, index) do
    with :ok <- validate_offset(header.local_offset, directory_offset, index),
         {:ok, local} <- parse(archive, directory_offset, header.local_offset, index),
         :ok <- validate_fields(local, header, index),
         {:ok, data_end} <- validate_data_range(local, header, directory_offset, index) do
      {:ok, {header.local_offset, data_end}}
    end
  end

  defp validate_offset(offset, directory_offset, _index)
       when offset + @fixed_size <= directory_offset do
    :ok
  end

  defp validate_offset(_offset, _directory_offset, index) do
    Error.single([:entries, index], :invalid_format, "has an invalid local-header offset")
  end

  defp parse(archive, directory_offset, offset, index) do
    available = directory_offset - offset
    bytes = binary_part(archive, offset, available)

    case bytes do
      <<@signature, _needed::little-16, flags::little-16, method::little-16, _time::little-16,
        _date::little-16, crc::little-32, compressed_size::little-32, size::little-32,
        name_size::little-16, extra_size::little-16, rest::binary>> ->
        local = %{
          flags: flags,
          method: method,
          crc: crc,
          compressed_size: compressed_size,
          size: size
        }

        take_variable(rest, name_size, extra_size, local, index)

      _malformed ->
        Error.single([:entries, index], :invalid_format, "has a malformed local ZIP header")
    end
  end

  defp take_variable(rest, name_size, extra_size, local, index) do
    case rest do
      <<name::binary-size(^name_size), _extra::binary-size(^extra_size), _data::binary>> ->
        {:ok,
         local
         |> Map.put(:name, name)
         |> Map.put(:data_offset, @fixed_size + name_size + extra_size)}

      _truncated ->
        Error.single([:entries, index], :invalid_format, "has truncated local ZIP metadata")
    end
  end

  defp validate_fields(local, header, _index)
       when local.name == header.name and local.flags == header.flags and
              local.method == header.method and local.crc == header.crc and
              local.compressed_size == header.compressed_size and local.size == header.size do
    :ok
  end

  defp validate_fields(_local, _header, index) do
    Error.single(
      [:entries, index],
      :invalid_format,
      "local ZIP header does not match the central directory"
    )
  end

  defp validate_data_range(local, header, directory_offset, index) do
    data_end = header.local_offset + local.data_offset + header.compressed_size
    data_range_result(data_end, directory_offset, index)
  end

  defp data_range_result(data_end, directory_offset, _index)
       when data_end <= directory_offset do
    {:ok, data_end}
  end

  defp data_range_result(_data_end, _directory_offset, index) do
    Error.single(
      [:entries, index],
      :invalid_format,
      "local ZIP data extends into the central directory"
    )
  end
end
