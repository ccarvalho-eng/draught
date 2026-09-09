defmodule Draught.CLI.Session.Catalog.PreviewTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Catalog.Preview

  test "normalizes, bounds, and round-trips a closed preview record" do
    prompt = "  Inspect\n\e[31mthe   " <> String.duplicate("parser ", 20)

    assert {:ok, preview} = Preview.new("session-01", prompt)
    assert preview.id == "session-01"

    assert preview.text ==
             "Inspect the parser parser parser parser parser parser parser parser par…"

    assert String.length(preview.text) == 72

    assert {:ok, encoded} = Preview.encode(preview)
    assert {:ok, ^preview} = Preview.decode(encoded)

    assert Jason.decode!(encoded) == %{
             "id" => "session-01",
             "schema" => "draught.cli.session.preview/v1",
             "text" => preview.text
           }
  end

  test "rejects noncanonical, extra, empty, and mismatched record values" do
    invalid = [
      %{
        "id" => "session-01",
        "schema" => "draught.cli.session.preview/v1",
        "text" => " leading"
      },
      %{
        "extra" => true,
        "id" => "session-01",
        "schema" => "draught.cli.session.preview/v1",
        "text" => "Inspect"
      },
      %{
        "id" => "session-01",
        "schema" => "draught.cli.session.preview/v1",
        "text" => ""
      },
      %{
        "id" => "../escape",
        "schema" => "draught.cli.session.preview/v1",
        "text" => "Inspect"
      }
    ]

    Enum.each(invalid, fn value ->
      encoded = Jason.encode!(value)
      assert {:error, error} = Preview.decode(encoded)
      assert error.code == "session_preview_invalid"
    end)
  end
end
