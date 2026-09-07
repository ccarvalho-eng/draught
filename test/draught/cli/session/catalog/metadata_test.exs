defmodule Draught.CLI.Session.Catalog.MetadataTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Catalog.Metadata

  @timestamp ~U[2026-09-07 12:00:00Z]

  test "round-trips closed versioned metadata" do
    metadata = Metadata.legacy("session-01")
    assert {:ok, renamed} = Metadata.rename(metadata, "Workspace review")
    archived = Metadata.archive(renamed, @timestamp)

    assert {:ok, encoded} = Metadata.encode(archived)
    assert {:ok, ^archived} = Metadata.decode(encoded)

    assert Jason.decode!(encoded) == %{
             "archived_at" => "2026-09-07T12:00:00Z",
             "id" => "session-01",
             "label" => "Workspace review",
             "schema" => "draught.cli.session.metadata/v1"
           }
  end

  test "rejects extra fields, invalid identifiers, labels, and timestamps" do
    invalid = [
      %{
        "archived_at" => nil,
        "id" => "../escape",
        "label" => nil,
        "schema" => "draught.cli.session.metadata/v1"
      },
      %{
        "archived_at" => nil,
        "id" => "session-01",
        "label" => "unsafe\e[31m",
        "schema" => "draught.cli.session.metadata/v1"
      },
      %{
        "archived_at" => "2026-09-07T09:00:00-03:00",
        "id" => "session-01",
        "label" => nil,
        "schema" => "draught.cli.session.metadata/v1"
      },
      %{
        "archived_at" => nil,
        "extra" => true,
        "id" => "session-01",
        "label" => nil,
        "schema" => "draught.cli.session.metadata/v1"
      }
    ]

    Enum.each(invalid, fn value ->
      encoded = Jason.encode!(value)
      assert {:error, error} = Metadata.decode(encoded)
      assert error.code == "session_metadata_invalid"
    end)
  end

  test "rejects encoding archive timestamps outside UTC" do
    non_utc = %{
      @timestamp
      | std_offset: 0,
        time_zone: "America/Sao_Paulo",
        utc_offset: -10_800,
        zone_abbr: "-03"
    }

    metadata =
      "session-01"
      |> Metadata.legacy()
      |> Metadata.archive(non_utc)

    assert {:error, error} = Metadata.encode(metadata)
    assert error.code == "session_metadata_invalid"
  end
end
