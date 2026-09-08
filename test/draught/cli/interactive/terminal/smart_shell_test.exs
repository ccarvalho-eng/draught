defmodule Draught.CLI.Interactive.Terminal.SmartShellTest do
  use ExUnit.Case, async: false

  alias Draught.CLI.Interactive.Terminal.SmartShell

  defmodule Shell do
    @spec start_interactive({module(), atom(), [term()]}) :: :ok
    def start_interactive({module, function, arguments}) do
      apply(module, function, arguments)
      :ok
    end
  end

  defmodule UnavailableShell do
    @spec start_interactive(term()) :: {:error, :unavailable}
    def start_interactive(_callback) do
      {:error, :unavailable}
    end
  end

  setup do
    slogan = Application.get_env(:stdlib, :shell_slogan, :missing)
    session_slogan = Application.get_env(:stdlib, :shell_session_slogan, :missing)

    on_exit(fn ->
      restore_environment(:shell_slogan, slogan)
      restore_environment(:shell_session_slogan, session_slogan)
    end)
  end

  test "runs the operation in a supervised custom-shell worker" do
    supervisor = start_supervised!({Task.Supervisor, name: nil})
    owner = self()

    operation = fn ->
      send(owner, {:operation_group, Process.group_leader()})
      7
    end

    assert SmartShell.run(operation, Shell, supervisor) == 7
    assert_receive {:operation_group, group_leader}
    assert group_leader == Process.group_leader()
  end

  test "falls back to the caller when a smart terminal is unavailable" do
    assert SmartShell.run(fn -> 5 end, UnavailableShell, self()) == 5
  end

  test "restores existing shell slogan configuration" do
    Application.put_env(:stdlib, :shell_slogan, "existing")
    Application.put_env(:stdlib, :shell_session_slogan, "session")
    supervisor = start_supervised!({Task.Supervisor, name: nil})

    assert SmartShell.run(fn -> 0 end, Shell, supervisor) == 0
    assert Application.get_env(:stdlib, :shell_slogan) == "existing"
    assert Application.get_env(:stdlib, :shell_session_slogan) == "session"
  end

  defp restore_environment(key, :missing) do
    Application.delete_env(:stdlib, key)
  end

  defp restore_environment(key, value) do
    Application.put_env(:stdlib, key, value)
  end
end
