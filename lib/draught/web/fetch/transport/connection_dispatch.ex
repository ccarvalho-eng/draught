defmodule Draught.Web.Fetch.Transport.ConnectionDispatch do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Validation.Error
  alias Draught.Web.Failure
  alias Draught.Web.Fetch.Transport.Configuration
  alias Draught.Web.Fetch.Transport.Limits
  alias Draught.Web.Fetch.Transport.RawResponse
  alias Draught.Web.Network.AddressPolicy
  alias Draught.Web.Policy
  alias Draught.Web.Target

  @doc """
  Resolves and validates a target before invoking an address-pinned connection.
  """
  @spec request(Target.t(), Policy.t(), Configuration.t(), integer()) ::
          {:ok, RawResponse.t()} | {:error, Normalized.t()}
  def request(target, policy, config, deadline) do
    with {:ok, addresses} <- resolve(target, config),
         {:ok, public} <- AddressPolicy.validate_all(addresses) do
      connect(target, hd(public), policy, config, deadline)
    end
  end

  defp resolve(target, config) do
    parsed =
      target.host
      |> String.to_charlist()
      |> :inet.parse_address()

    case parsed do
      {:ok, address} -> {:ok, [address]}
      {:error, :einval} -> invoke_resolver(config.resolver, target.host)
    end
  end

  defp invoke_resolver({module, configuration}, host) do
    case module.resolve(host, configuration) do
      {:ok, addresses} when is_list(addresses) -> {:ok, addresses}
      _result -> {:error, Failure.target_blocked()}
    end
  end

  defp connect(target, address, policy, config, deadline) do
    timeout = min(policy.request_timeout_ms, max(deadline - now(), 0))
    connect_with_timeout(timeout, target, address, policy, config)
  end

  defp connect_with_timeout(timeout, target, address, policy, config) when timeout > 0 do
    limits = %Limits{max_response_bytes: policy.max_response_bytes, timeout_ms: timeout}
    invoke_connection(config.connection, target, address, limits)
  end

  defp connect_with_timeout(_timeout, _target, _address, _policy, _config) do
    {:error, Failure.timeout()}
  end

  defp invoke_connection({module, configuration}, target, address, limits) do
    case module.request(target, address, limits, configuration) do
      {:ok, %RawResponse{} = response} ->
        canonical_response(response)

      {:ok, attributes} when is_map(attributes) or is_list(attributes) ->
        canonical_response(attributes)

      {:error, :too_large} ->
        {:error, Failure.response_too_large()}

      {:error, :timeout} ->
        {:error, Failure.timeout()}

      {:error, _reason} ->
        {:error, Failure.request_failed()}

      _result ->
        {:error, Failure.request_failed()}
    end
  end

  defp canonical_response(attributes) do
    case RawResponse.new(attributes) do
      {:ok, response} -> {:ok, response}
      {:error, %Error{}} -> {:error, Failure.request_failed()}
    end
  end

  defp now do
    System.monotonic_time(:millisecond)
  end
end
