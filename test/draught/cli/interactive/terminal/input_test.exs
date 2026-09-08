defmodule Draught.CLI.Interactive.Terminal.InputTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Terminal.Input

  defmodule Device do
    use GenServer

    @spec start_link(pid()) :: GenServer.on_start()
    def start_link(owner) do
      GenServer.start_link(__MODULE__, owner)
    end

    @impl GenServer
    def init(owner) do
      {:ok, owner}
    end

    @impl GenServer
    def handle_info({:io_request, recipient, reference, request}, owner) do
      send(owner, {:device_request, self(), recipient, reference, request})
      {:noreply, owner}
    end
  end

  setup do
    identity = make_ref()
    options = [name: nil, identity: identity]
    input = start_supervised!({Input, options})
    device = start_supervised!({Device, self()})
    on_exit(fn -> :persistent_term.erase({Input, identity}) end)
    %{device: device, input: input, options: options}
  end

  test "correlates asynchronous input and rejects concurrent reads", context do
    %{device: device, input: input} = context
    assert {:ok, reference} = Input.request_line(device, input)
    assert_receive {:device_request, ^device, ^input, ^reference, {:get_line, :unicode, ""}}
    assert {:error, :io} = Input.request_line(device, input)
    refute_receive {:device_request, _, _, _, _}

    send(input, {:io_reply, make_ref(), "incorrect"})
    refute_receive {:draught_terminal_input, _, _}
    send(input, {:io_reply, reference, "first\n"})
    assert_receive {:draught_terminal_input, ^reference, {:ok, "first\n"}}

    assert {:ok, second} = Input.request_line(device, input)
    refute second == reference
    send(input, {:io_reply, reference, "stale"})
    refute_receive {:draught_terminal_input, _, _}
    send(input, {:io_reply, second, "second\n"})
    assert_receive {:draught_terminal_input, ^second, {:ok, "second\n"}}
  end

  test "cancelled reads invalidate only their device and discard late replies", context do
    %{device: device, input: input} = context
    assert {:ok, reference} = Input.request_line(device, input)
    assert_receive {:device_request, ^device, ^input, ^reference, _request}
    assert :ok = Input.cancel_read(reference, input)
    send(input, {:io_reply, reference, "yes\n"})
    assert {:error, :io} = Input.request_line(device, input)
    refute_receive {:draught_terminal_input, _, _}
    refute_receive {:device_request, _, _, _, _}

    other = start_supervised!(Supervisor.child_spec({Device, self()}, id: :other))
    assert {:ok, other_reference} = Input.request_line(other, input)
    send(input, {:io_reply, other_reference, "independent"})
    assert_receive {:draught_terminal_input, ^other_reference, {:ok, "independent"}}
  end

  test "owner death invalidates its read even when a late reply races the monitor", context do
    %{device: device, input: input} = context
    parent = self()

    task = fn ->
      {:ok, reference} = Input.request_line(device, input)
      send(parent, {:owner_request, reference})

      receive do
        :stop -> :ok
      end
    end

    owner = start_supervised!(Supervisor.child_spec({Task, task}, id: :owner))
    monitor = Process.monitor(owner)
    assert_receive {:owner_request, reference}
    send(owner, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^owner, :normal}
    send(input, {:io_reply, reference, "late approval"})
    assert {:error, :io} = Input.request_line(device, input)
  end

  test "another caller cannot revoke an owned read", context do
    %{device: device, input: input} = context
    assert {:ok, reference} = Input.request_line(device, input)
    parent = self()

    task = fn ->
      :ok = Input.cancel_read(reference, input)
      send(parent, :attempted)
    end

    start_supervised!(Supervisor.child_spec({Task, task}, id: :other_owner))
    assert_receive :attempted
    send(input, {:io_reply, reference, "still owned"})
    assert_receive {:draught_terminal_input, ^reference, {:ok, "still owned"}}
  end

  test "normalizes unicode, EOF, interruption and invalid device replies", context do
    for {reply, expected} <- [
          {~c"café\n", {:ok, "café\n"}},
          {:eof, :eof},
          {{:error, :interrupted}, :interrupted},
          {{:error, :closed}, {:error, :io}},
          {[0xD800], {:error, :io}},
          {[:invalid], {:error, :io}},
          {%{unexpected: :payload}, {:error, :io}}
        ] do
      assert {:ok, reference} = Input.request_line(context.device, context.input)
      send(context.input, {:io_reply, reference, reply})
      assert_receive {:draught_terminal_input, ^reference, ^expected}
    end
  end

  test "device death fails the pending read and removes its ownership", context do
    %{device: device, input: input} = context
    assert {:ok, reference} = Input.request_line(device, input)
    stop_supervised!(Device)
    assert_receive {:draught_terminal_input, ^reference, {:error, :io}}
    replacement = start_supervised!({Device, self()})
    assert {:ok, replacement_reference} = Input.request_line(replacement, input)
    send(input, {:io_reply, replacement_reference, :eof})
    assert_receive {:draught_terminal_input, ^replacement_reference, :eof}
  end

  test "a coordinator restart cannot forget potentially outstanding input", context do
    assert {:ok, _reference} = Input.request_line(context.device, context.input)
    stop_supervised!(Input)
    restarted = start_supervised!({Input, context.options})
    assert {:error, :io} = Input.request_line(context.device, restarted)
    assert {:error, :io} = Input.read_line(context.device, restarted)
  end

  test "synchronous reads observe coordinator failure", context do
    %{device: device, input: input} = context
    parent = self()
    task = fn -> send(parent, {:read_result, Input.read_line(device, input)}) end
    start_supervised!(Supervisor.child_spec({Task, task}, id: :reader))
    assert_receive {:device_request, ^device, ^input, _reference, _request}
    stop_supervised!(Input)
    assert_receive {:read_result, {:error, :io}}
    assert {:error, :io} = Input.request_line(device, input)
    assert :ok = Input.cancel_read(make_ref(), input)
  end

  test "synchronous reads share the same completed and invalidated device ownership", context do
    %{device: device, input: input} = context
    parent = self()
    task = fn -> send(parent, {:read_result, Input.read_line(device, input)}) end
    start_supervised!(Supervisor.child_spec({Task, task}, id: :reader))
    assert_receive {:device_request, ^device, ^input, reference, _request}
    send(input, {:io_reply, reference, "line\n"})
    assert_receive {:read_result, {:ok, "line\n"}}

    assert {:ok, pending} = Input.request_line(device, input)
    assert :ok = Input.cancel_read(pending, input)
    assert {:error, :io} = Input.read_line(device, input)
  end

  test "a timed-out coordinator call revokes the delayed request before reuse", context do
    %{device: device, input: input} = context
    parent = self()

    task = fn ->
      result = Input.request_line(device, input)
      send(parent, {:request_result, result})

      receive do
        :stop -> :ok
      end
    end

    :ok = :sys.suspend(input)

    try do
      start_supervised!(Supervisor.child_spec({Task, task}, id: :reader))
      assert_receive {:request_result, {:error, :io}}, 6_000
    after
      :sys.resume(input)
    end

    assert_receive {:device_request, ^device, ^input, reference, _request}
    send(input, {:io_reply, reference, "too late"})
    assert {:error, :io} = Input.request_line(device, input)
    refute_receive {:draught_terminal_input, _, _}
  end
end
