defmodule Draught.CLI.Release.Application do
  @moduledoc """
  Boots the standalone executable without changing library or escript startup.

  The `cli` Mix target selects this callback when assembling a native release.
  The runtime supervisors start before command dispatch. Command execution
  retains control of the boot process and terminates the VM with the command's
  exit status.
  """

  use Application

  alias Burrito.Util.Args
  alias Draught.CLI.EntryPoint
  alias Draught.CLI.EntryPoint.Failure

  # Burrito calls this application callback as the executable entry point. It
  # intentionally does not return an OTP start result because EntryPoint halts
  # the VM with the CLI exit status after dispatch completes.
  @dialyzer {:nowarn_function, start: 2}

  @impl Application
  @spec start(Application.start_type(), term()) :: no_return()
  def start(_type, _arguments) do
    case Draught.Application.start(:normal, []) do
      {:ok, _runtime} -> run()
      _error -> halt(Failure.startup())
    end
  end

  @spec run() :: no_return()
  defp run do
    arguments = Args.argv()
    EntryPoint.main_started(arguments)
  end

  @spec halt(Failure.t()) :: no_return()
  defp halt({message, status}) do
    IO.write(:stderr, message)
    System.halt(status)
  end
end
