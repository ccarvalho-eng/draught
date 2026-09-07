defmodule Draught.Web.Target do
  @moduledoc """
  Canonical HTTP(S) request target validated before resolution.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_url_bytes 4_096
  @maximum_host_bytes 253
  @maximum_target_bytes 4_096
  @hostname ~r/\A[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\z/
  @numeric_host ~r/\A(?:0[xX][0-9A-Fa-f]+|[0-9]+)\z/

  @enforce_keys [:host, :logical_url, :port, :request_target, :scheme]
  defstruct [:host, :logical_url, :port, :request_target, :scheme]

  @type t :: %__MODULE__{
          host: String.t(),
          logical_url: String.t(),
          port: :inet.port_number(),
          request_target: String.t(),
          scheme: :http | :https
        }

  @doc "Parses one bounded URL without applying DNS or address policy."
  @spec new(term()) :: Error.result(t())
  def new(value) do
    with {:ok, url} <- Value.string(value, [:url]),
         true <- byte_size(url) <= @maximum_url_bytes,
         {:ok, uri} <- parse(url) do
      build(uri)
    else
      false -> Error.single([:url], :too_large, "exceeds the maximum URL byte size")
      {:error, %Error{}} = result -> result
    end
  end

  defp build(uri) do
    with {:ok, scheme, host, port} <- authority(uri),
         {:ok, request_target, logical} <- representation(uri, scheme, host) do
      {:ok,
       %__MODULE__{
         host: host,
         logical_url: logical,
         port: port,
         request_target: request_target,
         scheme: scheme
       }}
    end
  end

  defp authority(uri) do
    with {:ok, scheme} <- scheme(uri),
         {:ok, host} <- host(uri),
         {:ok, port} <- port(uri, scheme) do
      {:ok, scheme, host, port}
    end
  end

  defp representation(uri, scheme, host) do
    with {:ok, request_target} <- request_target(uri),
         :ok <- credentials(uri),
         :ok <- fragment(uri) do
      logical = URI.to_string(%{uri | scheme: Atom.to_string(scheme), host: host, fragment: nil})
      {:ok, request_target, logical}
    end
  end

  defp parse(url) do
    case URI.new(url) do
      {:ok, uri} -> {:ok, uri}
      {:error, _part} -> invalid("must be a valid URL")
    end
  end

  defp scheme(%URI{scheme: "http"}) do
    {:ok, :http}
  end

  defp scheme(%URI{scheme: "https"}) do
    {:ok, :https}
  end

  defp scheme(_uri) do
    invalid("must use HTTP or HTTPS")
  end

  defp host(%URI{host: host}) when is_binary(host) and byte_size(host) > 0 do
    canonical =
      host
      |> String.downcase()
      |> String.trim_trailing(".")

    cond do
      byte_size(canonical) > @maximum_host_bytes -> invalid("host exceeds the maximum byte size")
      Regex.match?(@numeric_host, canonical) -> invalid("host uses an ambiguous numeric form")
      ip_literal?(canonical) -> {:ok, canonical}
      Regex.match?(@hostname, canonical) and labels_valid?(canonical) -> {:ok, canonical}
      true -> invalid("host is not a valid ASCII hostname or address")
    end
  end

  defp host(_uri) do
    invalid("must include a host")
  end

  defp ip_literal?(host) do
    result =
      host
      |> String.to_charlist()
      |> :inet.parse_address()

    match?({:ok, _address}, result)
  end

  defp labels_valid?(host) do
    host
    |> String.split(".")
    |> Enum.all?(fn label -> byte_size(label) in 1..63 end)
  end

  defp port(%URI{port: port}, _scheme) when is_integer(port) and port in 1..65_535 do
    {:ok, port}
  end

  defp port(%URI{port: nil}, :http) do
    {:ok, 80}
  end

  defp port(%URI{port: nil}, :https) do
    {:ok, 443}
  end

  defp port(_uri, _scheme) do
    invalid("port is invalid")
  end

  defp request_target(uri) do
    path = uri.path || "/"
    target = append_query(path, uri.query)

    target_size(target)
  end

  defp append_query(path, nil) do
    path
  end

  defp append_query(path, query) do
    path <> "?" <> query
  end

  defp target_size(target) do
    target
    |> byte_size()
    |> target_size_result(target)
  end

  defp target_size_result(size, target) when size <= @maximum_target_bytes do
    {:ok, target}
  end

  defp target_size_result(_size, _target) do
    invalid("request target exceeds the maximum byte size")
  end

  defp credentials(%URI{userinfo: nil}) do
    :ok
  end

  defp credentials(_uri) do
    invalid("must not contain embedded credentials")
  end

  defp fragment(%URI{fragment: nil}) do
    :ok
  end

  defp fragment(_uri) do
    invalid("must not contain a fragment")
  end

  defp invalid(message) do
    Error.single([:url], :invalid_value, message)
  end
end
