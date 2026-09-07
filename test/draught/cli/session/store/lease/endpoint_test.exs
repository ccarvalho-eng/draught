defmodule Draught.CLI.Session.Store.Lease.EndpointTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Store.Lease.Endpoint

  test "derives stable distinct unprivileged candidates" do
    first =
      "a"
      |> String.duplicate(64)
      |> Endpoint.candidates()

    second =
      "b"
      |> String.duplicate(64)
      |> Endpoint.candidates()

    assert [_one, _two, _three, _four, _five, _six, _seven, _eight] = first
    assert Enum.uniq(first) == first
    refute first == second
    assert Enum.all?(first, &(&1 in 20_000..59_999))
  end
end
