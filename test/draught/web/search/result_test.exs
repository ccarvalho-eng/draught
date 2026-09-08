defmodule Draught.Web.Search.ResultTest do
  use ExUnit.Case, async: true

  alias Draught.Web.Output
  alias Draught.Web.Policy
  alias Draught.Web.Search.Result

  test "keeps query-distinct result URLs and deduplicates redacted provenance" do
    {:ok, policy} = Policy.new(max_search_results: 2)

    items = [
      %{title: "first", url: "https://example.com/item?id=1", snippet: "one"},
      %{title: "second", url: "https://example.com/item?id=2", snippet: "two"}
    ]

    assert {:ok, result} = Result.new(items, policy)
    assert {:ok, content, sources} = Output.search(result, 4_096)

    assert sources == ["https://example.com/item"]

    assert %{"data" => data} = Jason.decode!(content)

    assert Enum.map(data, & &1["url"]) == [
             "https://example.com/item?id=1",
             "https://example.com/item?id=2"
           ]
  end

  test "accepts an empty snippet without relaxing title or URL validation" do
    {:ok, policy} = Policy.new(max_search_results: 1)

    assert {:ok, result} =
             Result.new(
               [%{title: "Result", url: "https://example.com", snippet: ""}],
               policy
             )

    assert hd(result.items).snippet == ""

    assert {:error, _error} =
             Result.new([%{title: "", url: "https://example.com", snippet: ""}], policy)
  end
end
