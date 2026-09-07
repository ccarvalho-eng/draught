defmodule Draught.Web.Network.AddressPolicy do
  @moduledoc """
  Default-deny classification for resolved web destinations.
  """

  alias Draught.Web.Failure

  @type address :: :inet.ip_address()

  @doc "Allows a globally routable address and blocks local or special-use ranges."
  @spec validate(term()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def validate(address) do
    address
    |> public?()
    |> address_result()
  end

  @doc "Requires every resolved answer to be public before one is selected."
  @spec validate_all(term()) :: {:ok, [address()]} | {:error, Draught.Error.Normalized.t()}
  def validate_all([_address | _rest] = addresses) do
    addresses
    |> Enum.count_until(17)
    |> bounded_addresses(addresses)
  end

  def validate_all(_addresses) do
    {:error, Failure.target_blocked()}
  end

  defp bounded_addresses(count, addresses) when count <= 16 do
    addresses
    |> Enum.uniq()
    |> Enum.all?(&public?/1)
    |> all_result(addresses)
  end

  defp bounded_addresses(_count, _addresses) do
    {:error, Failure.target_blocked()}
  end

  defp public?({0, _b, _c, _d}) do
    false
  end

  defp public?({10, _b, _c, _d}) do
    false
  end

  defp public?({100, b, _c, _d}) when b in 64..127 do
    false
  end

  defp public?({127, _b, _c, _d}) do
    false
  end

  defp public?({169, 254, _c, _d}) do
    false
  end

  defp public?({172, b, _c, _d}) when b in 16..31 do
    false
  end

  defp public?({192, 0, 0, _d}) do
    false
  end

  defp public?({192, 0, 2, _d}) do
    false
  end

  defp public?({192, 88, 99, _d}) do
    false
  end

  defp public?({192, 168, _c, _d}) do
    false
  end

  defp public?({198, b, _c, _d}) when b in 18..19 do
    false
  end

  defp public?({198, 51, 100, _d}) do
    false
  end

  defp public?({203, 0, 113, _d}) do
    false
  end

  defp public?({a, b, c, d}) do
    Enum.all?([a, b, c, d], &byte?/1) and a in 1..223
  end

  defp public?({0x2001, 0, _c, _d, _e, _f, _g, _h}) do
    false
  end

  defp public?({0x2001, 2, 0, _d, _e, _f, _g, _h}) do
    false
  end

  defp public?({0x2001, b, _c, _d, _e, _f, _g, _h}) when b in 0x10..0x2F do
    false
  end

  defp public?({0x2001, 0xDB8, _c, _d, _e, _f, _g, _h}) do
    false
  end

  defp public?({0x2002, _b, _c, _d, _e, _f, _g, _h}) do
    false
  end

  defp public?({a, b, c, d, e, f, g, h}) do
    values = [a, b, c, d, e, f, g, h]
    Enum.all?(values, &word?/1) and a in 0x2000..0x3FFF
  end

  defp public?(_address) do
    false
  end

  defp byte?(value) do
    is_integer(value) and value in 0..255
  end

  defp word?(value) do
    is_integer(value) and value in 0..65_535
  end

  defp all_result(true, addresses) do
    {:ok, Enum.uniq(addresses)}
  end

  defp all_result(false, _addresses) do
    {:error, Failure.target_blocked()}
  end

  defp address_result(true) do
    :ok
  end

  defp address_result(false) do
    {:error, Failure.target_blocked()}
  end
end
