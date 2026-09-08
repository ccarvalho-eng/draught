defmodule Draught.Web.Search.Result.Item do
  @moduledoc """
  One bounded, untrusted web-search result.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value
  alias Draught.Web.Source
  alias Draught.Web.Target

  @maximum_title_bytes 512
  @maximum_snippet_bytes 4_096

  @enforce_keys [:title, :url, :source, :snippet]
  defstruct [:title, :url, :source, :snippet]

  @type t :: %__MODULE__{
          title: String.t(),
          url: String.t(),
          source: String.t(),
          snippet: String.t()
        }

  @doc "Builds one canonical result item."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:title, :url, :snippet]),
         {:ok, title} <- bounded(normalized, :title, @maximum_title_bytes),
         {:ok, url, source} <- urls(normalized),
         {:ok, snippet} <-
           bounded(normalized, :snippet, @maximum_snippet_bytes, allow_empty: true) do
      {:ok, %__MODULE__{title: title, url: url, source: source, snippet: snippet}}
    end
  end

  defp urls(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :url),
         {:ok, target} <- Target.new(value),
         {:ok, source} <- Source.sanitize(target.logical_url, [:url]) do
      {:ok, target.logical_url, source}
    end
  end

  defp bounded(attributes, key, maximum, options \\ []) do
    with {:ok, value} <- Value.required_string(attributes, key, options),
         true <- byte_size(value) <= maximum do
      {:ok, value}
    else
      false -> Error.single([key], :too_large, "exceeds the maximum byte size")
      {:error, %Error{}} = result -> result
    end
  end
end
