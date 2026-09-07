defmodule Draught.Conversation.Interchange.Bundle.Decoder.CentralDirectory do
  @moduledoc false

  alias Draught.Conversation.Interchange.Bundle.Decoder.EndOfCentralDirectory
  alias Draught.Conversation.Interchange.Bundle.Decoder.Header
  alias Draught.Conversation.Interchange.Bundle.Decoder.LocalHeader
  alias Draught.Validation.Error

  @file_signature <<0x02014B50::little-32>>
  @stored_method 0
  @utf8_flag 0x800
  @unix_system 3
  @dos_directory_attribute 0x10
  @file_type_mask 0o170000
  @regular_file_type 0o100000
  @zip64_16 0xFFFF
  @zip64_32 0xFFFFFFFF

  @doc "Validates central and local ZIP records before OTP allocates the ZIP table."
  @spec validate(binary(), EndOfCentralDirectory.t()) :: :ok | {:error, Error.t()}
  def validate(archive, directory) do
    records =
      binary_part(archive, directory.directory_offset, directory.directory_size)

    with {:ok, count} <-
           consume(records, archive, directory.directory_offset, 0, [], directory.entries) do
      validate_count(count, directory.entries)
    end
  end

  defp consume(<<>>, _archive, _directory_offset, count, _ranges, _expected_count) do
    {:ok, count}
  end

  defp consume(_records, _archive, _directory_offset, count, _ranges, expected_count)
       when count >= expected_count do
    Error.single([], :invalid_format, "central directory contains more entries than declared")
  end

  defp consume(records, archive, directory_offset, count, ranges, expected_count) do
    with {:ok, header, remaining} <- parse_record(records, count),
         :ok <- validate_entry(header, count),
         {:ok, range} <- LocalHeader.validate(archive, directory_offset, header, count),
         :ok <- validate_disjoint(range, ranges, count) do
      consume(
        remaining,
        archive,
        directory_offset,
        count + 1,
        [range | ranges],
        expected_count
      )
    end
  end

  defp parse_record(records, index) do
    case records do
      <<@file_signature, made_by::little-16, _needed::little-16, flags::little-16,
        method::little-16, _time::little-16, _date::little-16, crc::little-32,
        compressed_size::little-32, size::little-32, name_size::little-16, extra_size::little-16,
        comment_size::little-16, disk::little-16, _internal_attributes::little-16,
        external_attributes::little-32, local_offset::little-32, rest::binary>> ->
        header = %Header{
          made_by: made_by,
          flags: flags,
          method: method,
          crc: crc,
          compressed_size: compressed_size,
          size: size,
          disk: disk,
          external_attributes: external_attributes,
          local_offset: local_offset
        }

        take_variable(rest, name_size, extra_size, comment_size, header, index)

      _malformed ->
        Error.single(
          [:entries, index],
          :invalid_format,
          "has a malformed central-directory record"
        )
    end
  end

  defp take_variable(rest, name_size, extra_size, comment_size, header, index) do
    case rest do
      <<name::binary-size(^name_size), _extra::binary-size(^extra_size),
        _comment::binary-size(^comment_size), remaining::binary>> ->
        {:ok, %{header | name: name}, remaining}

      _truncated ->
        Error.single(
          [:entries, index],
          :invalid_format,
          "has truncated central-directory metadata"
        )
    end
  end

  defp validate_entry(header, index) do
    with :ok <- validate_disk(header.disk, index),
         :ok <- validate_flags(header.flags, index),
         :ok <- validate_method(header.method, index),
         :ok <- validate_dos_type(header.external_attributes, index),
         :ok <- validate_unix_type(header.made_by, header.external_attributes, index),
         :ok <- validate_non_zip64(header, index) do
      validate_stored_sizes(header.compressed_size, header.size, index)
    end
  end

  defp validate_disk(0, _index) do
    :ok
  end

  defp validate_disk(_disk, index) do
    Error.single([:entries, index], :invalid_format, "must be stored on the first ZIP disk")
  end

  defp validate_flags(flags, _index) when flags in [0, @utf8_flag] do
    :ok
  end

  defp validate_flags(_flags, index) do
    Error.single([:entries, index], :invalid_value, "contains unsupported ZIP flags")
  end

  defp validate_method(@stored_method, _index) do
    :ok
  end

  defp validate_method(_method, index) do
    Error.single([:entries, index], :invalid_value, "compression is not supported")
  end

  defp validate_dos_type(attributes, _index)
       when Bitwise.band(attributes, @dos_directory_attribute) == 0 do
    :ok
  end

  defp validate_dos_type(_attributes, index) do
    Error.single([:entries, index, :type], :invalid_value, "must be a regular file")
  end

  defp validate_unix_type(made_by, attributes, index) do
    system = Bitwise.bsr(made_by, 8)
    shifted_mode = Bitwise.bsr(attributes, 16)
    mode = Bitwise.band(shifted_mode, @file_type_mask)
    unix_type_result(system != @unix_system or mode in [0, @regular_file_type], index)
  end

  defp unix_type_result(true, _index) do
    :ok
  end

  defp unix_type_result(false, index) do
    Error.single([:entries, index, :type], :invalid_value, "must be a regular file")
  end

  defp validate_non_zip64(header, _index)
       when header.compressed_size != @zip64_32 and header.size != @zip64_32 and
              header.local_offset != @zip64_32 and header.disk != @zip64_16 do
    :ok
  end

  defp validate_non_zip64(_header, index) do
    Error.single([:entries, index], :invalid_format, "ZIP64 entries are not supported")
  end

  defp validate_stored_sizes(size, size, _index) do
    :ok
  end

  defp validate_stored_sizes(_compressed_size, _size, index) do
    Error.single([:entries, index], :invalid_format, "stored size values must match")
  end

  defp validate_disjoint(range, ranges, index) do
    ranges
    |> Enum.all?(&disjoint?(range, &1))
    |> disjoint_result(index)
  end

  defp disjoint?({first_start, first_end}, {second_start, second_end}) do
    first_end <= second_start or second_end <= first_start
  end

  defp disjoint_result(true, _index) do
    :ok
  end

  defp disjoint_result(false, index) do
    Error.single([:entries, index], :invalid_format, "overlaps another local ZIP entry")
  end

  defp validate_count(count, count) when count != @zip64_16 do
    :ok
  end

  defp validate_count(_actual, _expected) do
    Error.single([], :invalid_format, "central-directory entry count does not match its records")
  end
end
