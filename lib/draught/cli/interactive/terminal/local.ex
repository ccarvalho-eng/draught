defmodule Draught.CLI.Interactive.Terminal.Local do
  @moduledoc """
  Implements interactive input against the local standard input device.

  Idle chat prompts use the bounded raw editor when OTP exposes a compatible
  terminal. Unsupported terminals fall back to the supervised cooked reader.
  Approval and other synchronous prompts always remain on the cooked path.

  Synchronous prompts and asynchronous approvals share one input coordinator.
  Abandoning a pending read disables that device for the remaining VM lifetime;
  restoring terminal mode does not pretend to cancel an Erlang I/O request.
  """

  @behaviour Draught.CLI.Interactive.Terminal.Adapter

  alias Draught.CLI.Interactive.Completion
  alias Draught.CLI.Interactive.Completion.Context
  alias Draught.CLI.Interactive.Terminal.Editor
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
  def read_line(%Context{} = context, configuration) do
    read_editable(context, configuration)
  end

  defp read_editable(context, configuration) do
    case Editor.read(context, editor_driver(configuration)) do
      {:error, :unsupported} -> read_cooked(context)
      result -> result
    end
  end

  defp read_cooked(context) do
    device = Process.group_leader()
    configure_completion(device, Completion.function(context))

    try do
      Input.read_line(device)
    after
      configure_completion(device, &Completion.none/1)
    end
  end

  defp editor_driver(%{editor_driver: {module, configuration}}) when is_atom(module) do
    {module, configuration}
  end

  defp editor_driver(configuration) do
    {Draught.CLI.Interactive.Terminal.Editor.Driver.Local, configuration}
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
