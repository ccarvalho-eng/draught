defmodule Draught.Tool.Builtin.RunCommand.Subprocess do
  @moduledoc """
  Owns one bounded, cancellable operating-system subprocess.
  """

  alias Draught.Tool.Builtin.RunCommand.Execution
  alias Draught.Tool.Builtin.RunCommand.Failure
  alias Draught.Tool.Builtin.RunCommand.Subprocess.Handle
  alias Draught.Tool.Builtin.RunCommand.Subprocess.State

  @type result :: {:ok, String.t()} | {:error, Draught.Error.Normalized.t()}

  @doc "Starts a monitored subprocess owned by the calling process."
  @spec start(Execution.t()) :: {:ok, Handle.t()}
  def start(%Execution{} = execution) do
    owner = self()
    reference = make_ref()
    worker = fn -> open(owner, reference, execution) end
    {pid, monitor} = spawn_monitor(worker)
    {:ok, %Handle{monitor: monitor, pid: pid, reference: reference}}
  end

  @doc "Waits for a subprocess result."
  @spec await(Handle.t()) :: result()
  def await(%Handle{} = handle) do
    receive do
      {reference, result} when reference == handle.reference ->
        Process.demonitor(handle.monitor, [:flush])
        result

      {:DOWN, monitor, :process, pid, _reason}
      when monitor == handle.monitor and pid == handle.pid ->
        Failure.execution_failed()
    end
  end

  @doc "Requests cancellation of a running subprocess."
  @spec cancel(Handle.t()) :: :ok
  def cancel(%Handle{} = handle) do
    send(handle.pid, {:cancel, handle.reference})
    :ok
  end

  defp open(owner, reference, execution) do
    owner_monitor = Process.monitor(owner)
    name = port_name(execution)
    options = port_options(execution)
    port = Port.open(name, options)
    destination = self()
    timer = Process.send_after(destination, {:timeout, reference}, execution.timeout_ms)

    loop(%State{
      bytes: 0,
      execution: execution,
      output: [],
      owner: owner,
      owner_monitor: owner_monitor,
      port: port,
      reference: reference,
      timer: timer
    })
  end

  defp loop(state) do
    receive do
      message -> handle(message, state)
    end
  end

  defp handle({port, {:data, data}}, %State{port: port} = state) do
    receive_output(state, data)
  end

  defp handle({port, {:exit_status, status}}, %State{port: port} = state) do
    complete(state, status)
  end

  defp handle({:timeout, reference}, %State{reference: reference} = state) do
    stop(state, Failure.timeout())
  end

  defp handle({:cancel, reference}, %State{reference: reference} = state) do
    stop(state, Failure.cancelled())
  end

  defp handle(
         {:DOWN, monitor, :process, owner, _reason},
         %State{owner: owner, owner_monitor: monitor} = state
       ) do
    close(state)
  end

  defp handle(_message, state) do
    loop(state)
  end

  defp receive_output(state, data) do
    bytes = state.bytes + byte_size(data)

    bytes
    |> then(&(&1 <= state.execution.max_output_bytes))
    |> receive_output_result(state, data, bytes)
  end

  defp receive_output_result(true, state, data, bytes) do
    loop(%{state | bytes: bytes, output: [data | state.output]})
  end

  defp receive_output_result(false, state, _data, _bytes) do
    stop(state, Failure.output_too_large())
  end

  defp complete(state, status) do
    cancel_timer(state.timer)

    state.output
    |> Enum.reverse()
    |> IO.iodata_to_binary()
    |> format(status, state.execution.max_output_bytes)
    |> deliver(state)
  end

  defp format(output, status, maximum_bytes) do
    content = "Exit status: #{status}\n" <> output

    cond do
      byte_size(content) > maximum_bytes -> Failure.output_too_large()
      not String.valid?(content) -> Failure.invalid_output()
      true -> {:ok, content}
    end
  end

  defp stop(state, result) do
    cancel_timer(state.timer)
    close(state)
    deliver(result, state)
  end

  defp close(state) do
    case Port.info(state.port) do
      nil -> :ok
      _information -> Port.close(state.port)
    end
  end

  defp cancel_timer(timer) do
    Process.cancel_timer(timer, async: false, info: false)
  end

  defp deliver(result, state) do
    send(state.owner, {state.reference, result})
    :ok
  end

  defp port_name(execution) do
    {:spawn_executable, String.to_charlist(execution.executable)}
  end

  defp port_options(execution) do
    [
      :binary,
      :exit_status,
      :stderr_to_stdout,
      :use_stdio,
      {:args, Enum.map(execution.arguments, &String.to_charlist/1)},
      {:cd, String.to_charlist(execution.workspace)},
      {:env, execution.environment}
    ]
  end
end
