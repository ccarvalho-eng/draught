defmodule Draught.Provider.OpenAI.Configuration.Endpoint do
  @moduledoc """
  Validates and normalizes the HTTP base URL for a compatible endpoint.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @default_base_url "https://api.openai.com/v1"

  @doc "Builds a safe endpoint URI without embedded credentials or query data."
  @spec new(term()) :: Error.result(String.t())
  def new(value \\ nil)

  def new(nil) do
    new(@default_base_url)
  end

  def new(value) do
    with {:ok, string} <- Value.string(value, [:base_url]),
         {:ok, uri} <- URI.new(string),
         :ok <- validate_uri(uri) do
      normalized = normalize_uri(uri)
      {:ok, URI.to_string(normalized)}
    else
      {:error, %Error{}} = result -> result
      {:error, _reason} -> Error.single([:base_url], :invalid_value, "must be a valid HTTP URL")
    end
  end

  defp validate_uri(%URI{} = uri) do
    valid =
      uri.scheme in ["http", "https"] and valid_host?(uri.host) and is_nil(uri.userinfo) and
        is_nil(uri.query) and is_nil(uri.fragment)

    validate_uri_result(valid)
  end

  defp validate_uri_result(true) do
    :ok
  end

  defp validate_uri_result(false) do
    Error.single(
      [:base_url],
      :invalid_value,
      "must be an HTTP URL without credentials, query, or fragment"
    )
  end

  defp valid_host?(host) do
    is_binary(host) and byte_size(host) > 0 and
      not String.contains?(host, [" ", "\t", "\r", "\n"])
  end

  defp normalize_uri(%URI{path: path} = uri) do
    %{uri | path: normalize_path(path)}
  end

  defp normalize_path(nil) do
    nil
  end

  defp normalize_path(path) do
    String.trim_trailing(path, "/")
  end
end
