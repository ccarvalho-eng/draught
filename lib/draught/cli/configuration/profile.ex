defmodule Draught.CLI.Configuration.Profile do
  @moduledoc false

  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Value
  alias Draught.Provider.OpenAI.Configuration.Endpoint
  alias Draught.Provider.OpenAI.Configuration.Headers

  @allowed_keys MapSet.new(["provider", "base_url", "credential_env", "headers"])
  @sensitive_headers MapSet.new([
                       "api-key",
                       "authorization",
                       "proxy-authorization",
                       "x-api-key"
                     ])
  @credential_environment_pattern ~r/^[A-Z][A-Z0-9_]{0,127}$/

  @enforce_keys [:name, :provider, :base_url, :source]
  defstruct [:name, :provider, :base_url, :credential_env, :source, headers: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          provider: :ollama | :openai_compatible,
          base_url: String.t(),
          credential_env: String.t() | nil,
          headers: %{optional(String.t()) => String.t()},
          source: :defaults | :user
        }

  @doc "Builds a trusted provider profile from validated configuration attributes."
  @spec new(term(), term(), :defaults | :user) :: Error.result(t())
  def new(name, attributes, source) when is_map(attributes) do
    with {:ok, validated_name} <- Value.text(name, source, [:profiles, :name], 128),
         :ok <- reject_unknown_keys(attributes, source),
         {:ok, connection} <- connection(attributes, source),
         {:ok, headers} <- headers(attributes, source) do
      build(validated_name, connection, headers, source)
    end
  end

  def new(_name, _attributes, source) do
    Error.new(source, [:profiles], :invalid_type, "profile definitions must be objects")
  end

  defp reject_unknown_keys(attributes, source) do
    attributes
    |> Map.keys()
    |> Enum.all?(fn key -> MapSet.member?(@allowed_keys, key) end)
    |> unknown_keys_result(source)
  end

  defp unknown_keys_result(true, _source) do
    :ok
  end

  defp unknown_keys_result(false, source) do
    Error.new(source, [:profiles, :unknown], :unknown_key, "profile attribute is not supported")
  end

  defp required_provider(attributes, source) do
    case Map.fetch(attributes, "provider") do
      {:ok, value} -> Value.provider(value, source)
      :error -> Error.new(source, [:profiles, :provider], :required, "is required")
    end
  end

  defp connection(attributes, source) do
    with {:ok, provider} <- required_provider(attributes, source),
         {:ok, base_url} <- required_endpoint(attributes, source),
         {:ok, credential_env} <- credential_environment(attributes, source),
         :ok <- validate_transport(base_url, credential_env, source) do
      {:ok, {provider, base_url, credential_env}}
    end
  end

  defp required_endpoint(attributes, source) do
    with {:ok, value} <- fetch_endpoint(attributes, source),
         {:ok, bounded} <- Value.text(value, source, [:profiles, :base_url], 2_048) do
      endpoint(bounded, source)
    end
  end

  defp fetch_endpoint(attributes, source) do
    case Map.fetch(attributes, "base_url") do
      {:ok, value} -> {:ok, value}
      :error -> Error.new(source, [:profiles, :base_url], :required, "is required")
    end
  end

  defp endpoint(value, source) do
    case Endpoint.new(value) do
      {:ok, endpoint} ->
        {:ok, endpoint}

      {:error, _error} ->
        Error.new(source, [:profiles, :base_url], :invalid_value, "must be a safe HTTP URL")
    end
  end

  defp credential_environment(attributes, source) do
    case Map.fetch(attributes, "credential_env") do
      :error ->
        {:ok, nil}

      {:ok, value} ->
        with {:ok, name} <- Value.text(value, source, [:profiles, :credential_env], 128) do
          credential_environment_name(name, source)
        end
    end
  end

  defp credential_environment_name(name, source) do
    @credential_environment_pattern
    |> Regex.match?(name)
    |> credential_environment_result(name, source)
  end

  defp headers(attributes, source) do
    value = Map.get(attributes, "headers", %{})

    case Headers.new(value) do
      {:ok, headers} ->
        reject_sensitive_headers(headers, source)

      {:error, _error} ->
        Error.new(source, [:profiles, :headers], :invalid_value, "contains invalid headers")
    end
  end

  defp reject_sensitive_headers(headers, source) do
    safe =
      headers
      |> Map.keys()
      |> Enum.all?(fn name -> not MapSet.member?(@sensitive_headers, name) end)

    sensitive_headers_result(safe, headers, source)
  end

  defp validate_transport(_base_url, nil, _source) do
    :ok
  end

  defp validate_transport(base_url, _credential_env, source) do
    uri = URI.parse(base_url)
    secure = uri.scheme == "https" or loopback_host?(uri.host)
    transport_result(secure, source)
  end

  defp build(name, {provider, base_url, credential_env}, headers, source) do
    {:ok,
     %__MODULE__{
       name: name,
       provider: provider,
       base_url: base_url,
       credential_env: credential_env,
       headers: headers,
       source: source
     }}
  end

  defp credential_environment_result(true, name, _source) do
    {:ok, name}
  end

  defp credential_environment_result(false, _name, source) do
    Error.new(
      source,
      [:profiles, :credential_env],
      :invalid_value,
      "must be an environment variable name"
    )
  end

  defp sensitive_headers_result(true, headers, _source) do
    {:ok, headers}
  end

  defp sensitive_headers_result(false, _headers, source) do
    Error.new(
      source,
      [:profiles, :headers],
      :authority_denied,
      "must not contain credential headers"
    )
  end

  defp transport_result(true, _source) do
    :ok
  end

  defp transport_result(false, source) do
    Error.new(
      source,
      [:profiles, :base_url],
      :authority_denied,
      "credentialed remote profiles require HTTPS"
    )
  end

  defp loopback_host?("localhost") do
    true
  end

  defp loopback_host?(host) when is_binary(host) do
    host
    |> String.to_charlist()
    |> :inet.parse_address()
    |> loopback_address?()
  end

  defp loopback_host?(_host) do
    false
  end

  defp loopback_address?({:ok, {127, _second, _third, _fourth}}) do
    true
  end

  defp loopback_address?({:ok, {0, 0, 0, 0, 0, 0, 0, 1}}) do
    true
  end

  defp loopback_address?(_result) do
    false
  end
end

defimpl Inspect, for: Draught.CLI.Configuration.Profile do
  import Inspect.Algebra

  @spec inspect(Draught.CLI.Configuration.Profile.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect(_profile, _options) do
    concat(["#Draught.CLI.Configuration.Profile<redacted>"])
  end
end
