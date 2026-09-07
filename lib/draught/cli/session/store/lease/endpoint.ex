defmodule Draught.CLI.Session.Store.Lease.Endpoint do
  @moduledoc """
  Defines the local endpoint addresses used to coordinate a persistent-session lease.
  """

  @candidate_count 8
  @first_port 20_000
  @port_count 40_000

  @doc "Derives stable unprivileged loopback ports from a session scope key."
  @spec candidates(String.t()) :: [pos_integer()]
  def candidates(key) when is_binary(key) do
    derive(key, 0, [], %{}, 0)
  end

  defp derive(_key, _round, ports, _seen, @candidate_count) do
    Enum.reverse(ports)
  end

  defp derive(key, round, ports, seen, count) do
    digest = :crypto.hash(:sha256, [key, <<round::unsigned-integer-size(64)>>])
    {next_ports, next_seen, next_count} = collect(digest, ports, seen, count)
    derive(key, round + 1, next_ports, next_seen, next_count)
  end

  defp collect(_digest, ports, seen, @candidate_count) do
    {ports, seen, @candidate_count}
  end

  defp collect(<<>>, ports, seen, count) do
    {ports, seen, count}
  end

  defp collect(<<value::unsigned-integer-size(16), rest::binary>>, ports, seen, count) do
    port = @first_port + rem(value, @port_count)
    collect_port(Map.has_key?(seen, port), rest, port, ports, seen, count)
  end

  defp collect_port(true, rest, _port, ports, seen, count) do
    collect(rest, ports, seen, count)
  end

  defp collect_port(false, rest, port, ports, seen, count) do
    collect(rest, [port | ports], Map.put(seen, port, true), count + 1)
  end
end
