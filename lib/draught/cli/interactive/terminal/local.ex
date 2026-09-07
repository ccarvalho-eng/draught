defmodule Draught.CLI.Interactive.Terminal.Local do
  @moduledoc """
  Implements interactive line input against the local standard input device.

  Draught currently remains in the terminal's normal line mode, so restoration
  is intentionally idempotent. The callback remains explicit for future raw
  keyboard input without weakening shutdown guarantees.
  """

  @behaviour Draught.CLI.Interactive.Terminal.Adapter

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def interactive?(_configuration) do
    available =
      Code.ensure_loaded?(:prim_tty) and
        function_exported?(:prim_tty, :isatty, 1)

    interactive_result(available)
  end

  @impl Draught.CLI.Interactive.Terminal.Adapter
  def read_line(_configuration) do
    case IO.gets(:stdio, "") do
      data when is_binary(data) -> {:ok, data}
      :eof -> :eof
      {:error, _reason} -> {:error, :io}
    end
  rescue
    ErlangError -> {:error, :io}
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
