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
    Input.read_line(Process.group_leader())
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def request_line(_configuration) do
    Input.request_line(Process.group_leader())
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def cancel_read(reference, _configuration) do
    Input.cancel_read(reference)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def restore(_configuration) do
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
end
