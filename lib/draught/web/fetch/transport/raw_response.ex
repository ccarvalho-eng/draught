defmodule Draught.Web.Fetch.Transport.RawResponse do
  @moduledoc false

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:body, :headers, :status]
  defstruct [:body, :headers, :status]

  @type t :: %__MODULE__{
          body: binary(),
          headers: [{String.t(), String.t()}],
          status: non_neg_integer()
        }

  @maximum_headers 256
  @maximum_header_bytes 64 * 1024

  @doc "Reconstructs the bounded scalar response returned by a connection adapter."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:body, :headers, :status]),
         {:ok, body} <- body(normalized),
         {:ok, headers} <- headers(normalized),
         {:ok, status} <- status(normalized) do
      {:ok, %__MODULE__{body: body, headers: headers, status: status}}
    end
  end

  @doc "Returns all values for a lower-case response header name."
  @spec header(t(), String.t()) :: [String.t()]
  def header(%__MODULE__{headers: headers}, name) do
    for {header_name, value} <- headers, header_name == name, do: value
  end

  defp body(attributes) do
    with {:ok, body} <- Attributes.fetch_required(attributes, :body),
         true <- is_binary(body) do
      {:ok, body}
    else
      false -> Error.single([:body], :invalid_type, "must be bytes")
      {:error, %Error{}} = result -> result
    end
  end

  defp headers(attributes) do
    with {:ok, headers} <- Attributes.fetch_required(attributes, :headers),
         true <- is_list(headers) and length(headers) <= @maximum_headers,
         {:ok, canonical} <- normalize_headers(headers),
         true <- header_bytes(canonical) <= @maximum_header_bytes do
      {:ok, canonical}
    else
      false -> Error.single([:headers], :invalid_value, "must be a bounded list")
      {:error, %Error{}} = result -> result
    end
  end

  defp normalize_headers(headers) do
    headers
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {header, index}, {:ok, canonical} ->
      case normalize_header(header, index) do
        {:ok, value} -> {:cont, {:ok, [value | canonical]}}
        {:error, %Error{}} = result -> {:halt, result}
      end
    end)
    |> reverse()
  end

  defp normalize_header({name, value}, index) when is_binary(name) and is_binary(value) do
    with true <- String.valid?(name) and String.valid?(value),
         true <- byte_size(name) <= 256 and byte_size(value) <= 8_192 do
      {:ok, {String.downcase(name), value}}
    else
      false ->
        Error.single([:headers, index], :invalid_value, "must contain bounded UTF-8 strings")
    end
  end

  defp normalize_header(_header, index) do
    Error.single([:headers, index], :invalid_type, "must be a name and value pair")
  end

  defp reverse({:ok, headers}) do
    {:ok, Enum.reverse(headers)}
  end

  defp reverse({:error, %Error{}} = result) do
    result
  end

  defp status(attributes) do
    with {:ok, status} <- Attributes.fetch_required(attributes, :status) do
      Value.non_negative_integer(status, [:status])
    end
  end

  defp header_bytes(headers) do
    Enum.sum(for {name, value} <- headers, do: byte_size(name) + byte_size(value))
  end
end
