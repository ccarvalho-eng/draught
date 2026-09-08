defmodule Draught.Execution.BoundedTask.StreamTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.BoundedTask.Stream
  alias Draught.Execution.Runner.Failure.Runtime

  test "applies the absolute provider deadline while a sink is blocked" do
    owner = self()
    timeout = Runtime.provider_timeout()

    effect = fn relay ->
      send(owner, {:provider, self()})

      receive do
        :deliver -> :ok
      end

      :ok = relay.(:event)
      {:ok, :late}
    end

    sink = fn :event ->
      send(owner, {:sink_blocked, self()})

      receive do
        :release -> :ok
      end
    end

    stream =
      Task.async(fn ->
        Stream.run(
          effect,
          sink,
          2_000,
          1_024,
          timeout,
          Runtime.provider_crashed(),
          Runtime.provider_output_too_large()
        )
      end)

    assert_receive {:provider, provider}, 500
    Process.sleep(750)
    send(provider, :deliver)
    assert_receive {:sink_blocked, sink}, 500
    assert Task.await(stream, 1_600) == {:error, timeout}
    refute Process.alive?(provider)
    refute Process.alive?(sink)
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
