defmodule Draught.Execution.BoundedTask.StreamTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.BoundedTask.Stream
  alias Draught.Execution.Runner.Failure.Runtime

  test "applies the absolute provider deadline while a sink is blocked" do
    owner = self()
    timeout = Runtime.provider_timeout()

    effect = fn relay ->
      send(owner, {:provider, self()})
      :ok = relay.(:event)
      {:ok, :late}
    end

    sink = fn :event ->
      Process.sleep(100)
      :ok
    end

    assert Stream.run(
             effect,
             sink,
             20,
             1_024,
             timeout,
             Runtime.provider_crashed(),
             Runtime.provider_output_too_large()
           ) == {:error, timeout}

    assert_receive {:provider, provider}
    refute Process.alive?(provider)
  end

  test "does not let the provider advance before sink acknowledgement" do
    owner = self()

    effect = fn relay ->
      :ok = relay.(:first)
      send(owner, :provider_advanced)
      :ok = relay.(:second)
      :done
    end

    sink = fn event ->
      send(owner, {:sink, event, self()})

      receive do
        :continue -> :ok
      end
    end

    task =
      Task.async(fn ->
        Stream.run(
          effect,
          sink,
          1_000,
          1_024,
          Runtime.provider_timeout(),
          Runtime.provider_crashed(),
          Runtime.provider_output_too_large()
        )
      end)

    assert_receive {:sink, :first, first_sink}
    refute_receive :provider_advanced
    send(first_sink, :continue)
    assert_receive :provider_advanced
    assert_receive {:sink, :second, second_sink}
    send(second_sink, :continue)
    assert Task.await(task) == :done
  end
end
