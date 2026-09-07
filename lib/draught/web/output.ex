defmodule Draught.Web.Output do
  @moduledoc """
  Encodes validated web results into bounded external-data envelopes.

  Every envelope marks its payload as untrusted and returns sanitized source URLs
  separately for provenance tracking.
  """

  alias Draught.Web.Fetch.Response
  alias Draught.Web.Output.Budget
  alias Draught.Web.Search.Result
  alias Draught.Web.Search.Result.Item

  @doc "Renders search results as a fixed external-data envelope."
  @spec search(Result.t(), pos_integer()) ::
          {:ok, String.t(), [String.t()]} | {:error, Jason.EncodeError.t() | :too_large}
  def search(%Result{items: items}, maximum_bytes) do
    data = Enum.map(items, &search_item/1)

    sources =
      items
      |> Enum.map(& &1.source)
      |> Enum.uniq()

    encode(
      %{
        "content_type" => "application/vnd.draught.web-search+json",
        "data" => data,
        "trust" => "untrusted"
      },
      sources,
      maximum_bytes
    )
  end

  @doc "Renders a fetched page as a fixed external-data envelope."
  @spec fetch(Response.t(), pos_integer()) ::
          {:ok, String.t(), [String.t()]} | {:error, Jason.EncodeError.t() | :too_large}
  def fetch(%Response{} = response, maximum_bytes) do
    sources = Enum.concat(response.redirects, [response.final_url])

    encode(
      %{
        "content_type" => response.content_type,
        "data" => response.content,
        "source" => response.final_url,
        "trust" => "untrusted"
      },
      Enum.uniq(sources),
      maximum_bytes
    )
  end

  defp search_item(%Item{} = item) do
    %{"snippet" => item.snippet, "title" => item.title, "url" => item.url}
  end

  defp encode(value, sources, maximum_bytes) do
    with :ok <- Budget.validate(value, maximum_bytes),
         {:ok, content} <- Jason.encode(value) do
      {:ok, content, sources}
    end
  end
end
