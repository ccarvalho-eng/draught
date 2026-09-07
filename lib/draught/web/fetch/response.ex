defmodule Draught.Web.Fetch.Response do
  @moduledoc """
  Bounded textual response returned by a guarded fetch adapter.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value
  alias Draught.Web.Policy
  alias Draught.Web.Source

  @content_types [
    "application/json",
    "application/xhtml+xml",
    "application/xml",
    "text/html",
    "text/plain",
    "text/xml"
  ]

  @enforce_keys [:content, :content_type, :final_url, :redirects]
  defstruct [:content, :content_type, :final_url, :redirects]

  @type t :: %__MODULE__{
          content: String.t(),
          content_type: String.t(),
          final_url: String.t(),
          redirects: [String.t()]
        }

  @doc "Reconstructs a response under byte, type, and redirect limits."
  @spec new(map() | keyword(), Policy.t()) :: Error.result(t())
  def new(attributes, %Policy{} = policy) do
    keys = [:content, :content_type, :final_url, :redirects]

    with {:ok, normalized} <- Attributes.normalize(attributes, keys),
         {:ok, content} <- content(normalized, policy),
         {:ok, content_type} <- content_type(normalized),
         {:ok, final_url} <- url(normalized, :final_url),
         {:ok, redirects} <- redirects(normalized, policy) do
      {:ok,
       %__MODULE__{
         content: content,
         content_type: content_type,
         final_url: final_url,
         redirects: redirects
       }}
    end
  end

  @doc "Lists the content types accepted by the guarded fetch boundary."
  @spec content_types() :: [String.t()]
  def content_types do
    @content_types
  end

  @doc "Normalizes and validates one response content type."
  @spec validate_content_type(term()) :: Error.result(String.t())
  def validate_content_type(value) do
    with {:ok, raw} <- Value.string(value, [:content_type]),
         canonical <- canonical_content_type(raw),
         true <- canonical in @content_types do
      {:ok, canonical}
    else
      false ->
        Error.single([:content_type], :invalid_value, "is not an allowed text content type")

      {:error, %Error{}} = result ->
        result
    end
  end

  defp content(attributes, policy) do
    with {:ok, content} <- Value.required_string(attributes, :content),
         true <- byte_size(content) <= policy.max_response_bytes do
      {:ok, content}
    else
      false -> Error.single([:content], :too_large, "exceeds the response byte limit")
      {:error, %Error{}} = result -> result
    end
  end

  defp content_type(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :content_type) do
      validate_content_type(value)
    end
  end

  defp canonical_content_type(value) do
    value
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp redirects(attributes, policy) do
    values = Map.get(attributes, :redirects, [])

    redirects(values, policy.max_redirects, is_list(values))
  end

  defp redirects(values, maximum, true) do
    values
    |> Enum.count_until(maximum + 1)
    |> bounded_redirects(values, maximum)
  end

  defp redirects(_values, _maximum, false) do
    Error.single([:redirects], :invalid_value, "must be a bounded list of URLs")
  end

  defp bounded_redirects(count, values, maximum) when count <= maximum do
    normalize_urls(values)
  end

  defp bounded_redirects(_count, _values, _maximum) do
    Error.single([:redirects], :invalid_value, "must be a bounded list of URLs")
  end

  defp normalize_urls(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, urls} ->
      case Source.sanitize(value, [:redirects, index]) do
        {:ok, url} -> {:cont, {:ok, [url | urls]}}
        {:error, %Error{}} = result -> {:halt, result}
      end
    end)
    |> reverse()
  end

  defp reverse({:ok, urls}) do
    {:ok, Enum.reverse(urls)}
  end

  defp reverse({:error, %Error{}} = result) do
    result
  end

  defp url(attributes, key) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      Source.sanitize(value, [key])
    end
  end
end
