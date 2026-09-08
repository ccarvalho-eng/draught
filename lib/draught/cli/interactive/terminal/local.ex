defmodule Draught.CLI.Interactive.Terminal.Local do
  @moduledoc """
  Implements interactive line input against the local standard input device.

  Draught currently remains in the terminal's normal line mode, so restoration
  is intentionally idempotent. The callback remains explicit for future raw
  keyboard input without weakening shutdown guarantees.

  Synchronous prompts and asynchronous approvals share one input coordinator.
  Abandoning a pending read disables that device for the remaining VM lifetime;
  restoring terminal mode does not pretend to cancel an Erlang I/O request.
  """

  @behaviour Draught.CLI.Interactive.Terminal.Adapter

  alias Draught.CLI.Interactive.Completion
  alias Draught.CLI.Interactive.Completion.Context
  alias Draught.CLI.Interactive.Terminal.Input

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def interactive?(_configuration) do
    available =
      Code.ensure_loaded?(:prim_tty) and
        function_exported?(:prim_tty, :isatty, 1)

    interactive_result(available)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def read_line(_configuration) do
    device = Process.group_leader()
    configure_completion(device, &Completion.none/1)
    Input.read_line(device)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def read_line(%Context{} = context, _configuration) do
    device = Process.group_leader()
    configure_completion(device, Completion.function(context))

    try do
      Input.read_line(device)
    after
      configure_completion(device, &Completion.none/1)
    end
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def request_line(_configuration) do
    device = Process.group_leader()
    configure_completion(device, &Completion.none/1)
    Input.request_line(device)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def cancel_read(reference, _configuration) do
    Input.cancel_read(reference)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def restore(_configuration) do
    configure_completion(Process.group_leader(), &Completion.none/1)
    :ok
  end

  defp interactive_result(true) do
    :prim_tty.isatty(:stdin) == true
  rescue
    ErlangError -> false
  catch
    _kind, _reason -> false
  end

  defp interactive_result(false) do
    false
  end

  defp configure_completion(device, function) do
    case :io.setopts(device, expand_fun: function) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  catch
    :exit, _reason -> :ok
  end
end
