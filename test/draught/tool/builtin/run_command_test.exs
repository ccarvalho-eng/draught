defmodule Draught.Tool.Builtin.RunCommandTest do
  use ExUnit.Case, async: false

  alias Draught.Tool
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Builtin.RunCommand
  alias Draught.Tool.Builtin.RunCommand.Environment
  alias Draught.Tool.Builtin.RunCommand.Execution
  alias Draught.Tool.Builtin.RunCommand.Subprocess
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  @receive_timeout 1_000
  @moduletag :tmp_dir

  defmodule ApprovalPolicy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(request, configuration) do
      send(configuration.owner, {:approval_request, request})
      Decision.new(outcome: configuration.outcome)
    end
  end

  test "denial does not start the command and exposes only bounded metadata", %{
    tmp_dir: workspace
  } do
    target = Path.join(workspace, "created.txt")
    context = context(workspace, :deny)

    assert {:ok, result} = execute(workspace, "/usr/bin/touch", [target], context)
    assert result.error.code == "approval_denied"
    refute File.exists?(target)

    assert_received {:approval_request, request}
    assert request.target == "/usr/bin/touch"
    assert request.arguments_summary == "1 arguments; isolated environment"
    refute String.contains?(request.arguments_summary, target)
  end

  test "runs an executable without interpreting argument text as shell input", %{
    tmp_dir: workspace
  } do
    target = Path.join(workspace, "created.txt")
    argument = "$(touch #{target})"

    assert {:ok, result} =
             execute(workspace, "/bin/echo", [argument], context(workspace, :allow))

    assert result.status == :success
    assert result.content == "Exit status: 0\n#{argument}\n"
    refute File.exists?(target)
  end

  test "uses the canonical workspace and a scrubbed environment", %{tmp_dir: workspace} do
    assert {:ok, pwd_result} =
             execute(workspace, "/bin/pwd", [], context(workspace, :allow))

    assert pwd_result.content == "Exit status: 0\n#{workspace}\n"

    assert {:ok, env_result} =
             execute(workspace, "/usr/bin/env", [], context(workspace, :allow))

    assert env_result.content =~ "HOME=#{workspace}\n"
    assert env_result.content =~ "GIT_TERMINAL_PROMPT=0\n"
    refute env_result.content =~ "SSH_AUTH_SOCK="
  end

  test "returns a timeout and closes a long-running subprocess", %{tmp_dir: workspace} do
    policy = policy(timeout_ms: 20)
    context = context(workspace, :allow, policy)

    assert {:ok, result} = execute(workspace, "/bin/sleep", ["1"], context)
    assert result.error.kind == :timeout
    assert result.error.code == "command_timeout"
  end

  test "rejects output beyond the configured byte limit", %{tmp_dir: workspace} do
    policy = policy(max_output_bytes: 128)
    context = context(workspace, :allow, policy)

    assert {:ok, result} = execute(workspace, "/usr/bin/yes", [], context)
    assert result.error.code == "command_output_too_large"
  end

  test "a subprocess handle supports explicit cancellation", %{tmp_dir: workspace} do
    execution = sleep_execution(workspace)

    assert {:ok, handle} = Subprocess.start(execution)
    assert :ok = Subprocess.cancel(handle)
    assert {:error, error} = Subprocess.await(handle)
    assert error.kind == :cancellation
    assert error.code == "command_cancelled"
  end

  test "a subprocess closes when its owner exits", %{tmp_dir: workspace} do
    parent = self()
    execution = sleep_execution(workspace)

    owner =
      spawn(fn ->
        {:ok, handle} = Subprocess.start(execution)
        send(parent, {:subprocess_started, self(), handle})
        Subprocess.await(handle)
      end)

    assert_receive {:subprocess_started, ^owner, handle}, @receive_timeout
    subprocess_monitor = Process.monitor(handle.pid)
    Process.exit(owner, :kill)

    assert_receive {:DOWN, ^subprocess_monitor, :process, subprocess, :normal}, @receive_timeout
    assert subprocess == handle.pid
  end

  defp execute(_workspace, executable, arguments, context) do
    {:ok, definition} = RunCommand.definition()
    {:ok, registry} = Registry.new([definition])

    Tool.execute(
      registry,
      %{
        id: "call-1",
        name: "run_command",
        arguments: %{"arguments" => arguments, "executable" => executable}
      },
      context
    )
  end

  defp context(workspace, outcome, policy \\ policy()) do
    {:ok, context} =
      Context.new(
        workspace: workspace,
        policy: policy,
        approval: {ApprovalPolicy, %{owner: self(), outcome: outcome}}
      )

    context
  end

  defp policy(options \\ []) do
    options
    |> Keyword.put_new(:allowed_risks, [:execute])
    |> Policy.new()
    |> then(fn {:ok, policy} -> policy end)
  end

  defp sleep_execution(workspace) do
    {:ok, environment, _path} = Environment.build(workspace, %{})

    Execution.new(
      arguments: ["1"],
      environment: environment,
      executable: "/bin/sleep",
      max_output_bytes: 128,
      timeout_ms: 5_000,
      workspace: workspace
    )
  end
end
