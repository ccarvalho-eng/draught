defmodule Draught.Web.Source do
  @moduledoc """
  Sanitizes source URLs before they enter tool output or provenance records.

  Sources are bounded HTTP(S) URLs with an ASCII host. Embedded credentials,
  queries, and fragments are never retained.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_url_bytes 4_096
  @host ~r/\A[A-Za-z0-9.-]+\z/

  @doc "Returns a bounded HTTP(S) source without credentials, query, or fragment."
  @spec sanitize(term(), [term()]) :: Error.result(String.t())
  def sanitize(value, path \\ [:source]) do
    with {:ok, url} <- Value.string(value, path),
         true <- byte_size(url) <= @maximum_url_bytes,
         {:ok, uri} <- parse(url, path),
         :ok <- validate(uri, path) do
      sanitized = %{uri | userinfo: nil, query: nil, fragment: nil}
      {:ok, URI.to_string(sanitized)}
    else
      false -> Error.single(path, :too_large, "exceeds the maximum URL byte size")
      {:error, %Error{}} = result -> result
    end
  end

  defp parse(url, path) do
    case URI.new(url) do
      {:ok, uri} -> {:ok, uri}
      {:error, _part} -> Error.single(path, :invalid_value, "must be a valid URL")
    end
  end

  defp validate(%URI{scheme: scheme, host: host, userinfo: nil}, _path)
       when scheme in ["http", "https"] and is_binary(host) and byte_size(host) > 0 do
    host
    |> valid_host?()
    |> host_result()
  end

  defp validate(%URI{userinfo: userinfo}, path) when is_binary(userinfo) do
    Error.single(path, :invalid_value, "must not contain embedded credentials")
  end

  defp validate(_uri, path) do
    Error.single(path, :invalid_value, "must use HTTP or HTTPS with a host")
  end

  defp address?(host) do
    parsed =
      host
      |> String.to_charlist()
      |> :inet.parse_address()

    match?({:ok, _address}, parsed)
  end

  defp valid_host?(host) do
    address?(host) or Regex.match?(@host, host)
  end

  defp host_result(true) do
    :ok
  end

  defp host_result(false) do
    Error.single([:host], :invalid_value, "must be an ASCII hostname or address")
  end
end
