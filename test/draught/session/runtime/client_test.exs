defmodule Draught.Session.Runtime.ClientTest do
  use ExUnit.Case, async: true

  alias Draught.Session.Runtime.Client

  test "normalizes a session process that exits while handling a call" do
    identifier = "dying-client-#{System.unique_integer([:positive, :monotonic])}"
    owner = self()

    spawn(fn ->
      Registry.register(Draught.Session.Registry, identifier, nil)
      send(owner, :registered)

      receive do
        {:"$gen_call", _from, :status} -> exit(:shutdown)
      end
    end)

    assert_receive :registered
    assert {:error, %{code: "session_call_failed"}} = Client.call(identifier, :status)
  end

  test "reports unknown completion when a session call times out" do
    identifier = "slow-client-#{System.unique_integer([:positive, :monotonic])}"
    owner = self()

    session =
      spawn(fn ->
        Registry.register(Draught.Session.Registry, identifier, nil)
        send(owner, :registered)

        receive do
          {:"$gen_call", _from, :status} -> Process.sleep(:infinity)
        end
      end)

    on_exit(fn -> Process.exit(session, :kill) end)

    assert_receive :registered

    assert {:error, error} = Client.call(identifier, :status, 10)
    assert error.code == "session_call_timeout"
    assert error.kind == :timeout
    assert error.retryable == false
    assert error.message =~ "may still complete"
  end
end
