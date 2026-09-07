defmodule Draught.Web.Network.Resolver.System do
  @moduledoc """
  Resolves hostnames through the system IPv4 and IPv6 resolver.

  Successful answers from both address families are combined and deduplicated.
  Address policy remains the responsibility of the caller.
  """

  @behaviour Draught.Web.Network.Resolver

  @impl Draught.Web.Network.Resolver
  def resolve(host, _configuration) do
    characters = String.to_charlist(host)
    ipv4 = :inet.getaddrs(characters, :inet)
    ipv6 = :inet.getaddrs(characters, :inet6)
    combine(ipv4, ipv6)
  end

  defp combine({:ok, ipv4}, {:ok, ipv6}) do
    {:ok, Enum.uniq(ipv4 ++ ipv6)}
  end

  defp combine({:ok, ipv4}, {:error, _reason}) when ipv4 != [] do
    {:ok, Enum.uniq(ipv4)}
  end

  defp combine({:error, _reason}, {:ok, ipv6}) when ipv6 != [] do
    {:ok, Enum.uniq(ipv6)}
  end

  defp combine(_ipv4, _ipv6) do
    {:error, :resolution_failed}
  end
end
