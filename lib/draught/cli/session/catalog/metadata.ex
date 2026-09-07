defmodule Draught.CLI.Session.Catalog.Metadata do
  @moduledoc """
  Defines the closed versioned metadata record for one persistent CLI session.

  Missing metadata represents a legacy active session. Archival is a reversible
  state transition and never renames or deletes the durable session directory.
  """

  alias Draught.CLI.Session.Catalog.Name
  alias Draught.CLI.Session.Failure
  alias Draught.Session.Identifier

  @schema "draught.cli.session.metadata/v1"
  @enforce_keys [:archived_at, :id, :label, :version]
  defstruct [:archived_at, :id, :label, :version]

  @type t :: %__MODULE__{
          archived_at: DateTime.t() | nil,
          id: String.t(),
          label: String.t() | nil,
          version: 1
        }

  @doc "Returns the implicit metadata used by sessions created before this record existed."
  @spec legacy(String.t()) :: t()
  def legacy(id) do
    %__MODULE__{archived_at: nil, id: id, label: nil, version: 1}
  end

  @doc "Changes the display name after validating it."
  @spec rename(t(), term()) :: {:ok, t()} | {:error, Draught.Validation.Error.t()}
  def rename(%__MODULE__{} = metadata, name) do
    with {:ok, validated} <- Name.validate(name) do
      {:ok, %{metadata | label: validated}}
    end
  end

  @doc "Returns metadata in the archived state."
  @spec archive(t(), DateTime.t()) :: t()
  def archive(%__MODULE__{} = metadata, %DateTime{} = timestamp) do
    %{metadata | archived_at: DateTime.truncate(timestamp, :second)}
  end

  @doc "Returns metadata in the active state."
  @spec restore(t()) :: t()
  def restore(%__MODULE__{} = metadata) do
    %{metadata | archived_at: nil}
  end

  @doc "Encodes one validated metadata record as a closed JSON object."
  @spec encode(t()) :: {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(%__MODULE__{version: 1} = metadata) do
    with {:ok, id} <- Identifier.new(metadata.id),
         {:ok, label} <- decode_label(metadata.label),
         {:ok, archived_at} <- encode_timestamp(metadata.archived_at) do
      encode_value(id, label, archived_at)
    else
      _result -> {:error, Failure.invalid_metadata()}
    end
  end

  def encode(%__MODULE__{}) do
    {:error, Failure.invalid_metadata()}
  end

  @doc "Decodes one strict metadata record without creating atoms."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(encoded) when is_binary(encoded) do
    case Jason.decode(encoded) do
      {:ok, value} -> decode_value(value)
      {:error, _reason} -> {:error, Failure.invalid_metadata()}
    end
  end

  def decode(_encoded) do
    {:error, Failure.invalid_metadata()}
  end

  defp decode_value(
         %{
           "archived_at" => archived_at,
           "id" => id,
           "label" => label,
           "schema" => @schema
         } = value
       )
       when map_size(value) == 4 do
    with {:ok, validated_id} <- Identifier.new(id),
         {:ok, validated_label} <- decode_label(label),
         {:ok, validated_timestamp} <- decode_timestamp(archived_at) do
      {:ok,
       %__MODULE__{
         archived_at: validated_timestamp,
         id: validated_id,
         label: validated_label,
         version: 1
       }}
    else
      _result -> {:error, Failure.invalid_metadata()}
    end
  end

  defp decode_value(_value) do
    {:error, Failure.invalid_metadata()}
  end

  defp decode_label(nil) do
    {:ok, nil}
  end

  defp decode_label(name) do
    Name.validate(name)
  end

  defp decode_timestamp(nil) do
    {:ok, nil}
  end

  defp decode_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, timestamp, 0} -> normalized_timestamp(timestamp, value)
      _result -> :error
    end
  end

  defp decode_timestamp(_value) do
    :error
  end

  defp normalized_timestamp(timestamp, encoded) do
    normalized = DateTime.truncate(timestamp, :second)

    case DateTime.to_iso8601(normalized) do
      ^encoded -> {:ok, normalized}
      _other -> :error
    end
  end

  defp encode_timestamp(nil) do
    {:ok, nil}
  end

  defp encode_timestamp(
         %DateTime{utc_offset: utc_offset, std_offset: standard_offset} = timestamp
       )
       when utc_offset + standard_offset == 0 do
    encoded =
      timestamp
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    {:ok, encoded}
  end

  defp encode_timestamp(_value) do
    :error
  end

  defp encode_value(id, label, archived_at) do
    value = %{
      "archived_at" => archived_at,
      "id" => id,
      "label" => label,
      "schema" => @schema
    }

    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, _reason} -> {:error, Failure.invalid_metadata()}
    end
  end
end
