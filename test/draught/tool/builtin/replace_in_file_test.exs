defmodule Draught.Tool.Builtin.ReplaceInFileTest do
  use ExUnit.Case, async: false

  alias Draught.Tool
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Builtin.ReplaceInFile
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Mutation.Queue
  alias Draught.Tool.Registry

  @moduletag :tmp_dir

  defmodule ApprovalPolicy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(request, configuration) do
      send(configuration.owner, {:approval_request, request})
      Decision.new(outcome: configuration.outcome)
    end
  end

  defmodule BlockingOperation do
    @behaviour Draught.Tool.Mutation.Operation

    @impl Draught.Tool.Mutation.Operation
    def run({owner, id}) do
      send(owner, {:started, id})

      receive do
        {:continue, ^id} -> {:ok, Atom.to_string(id)}
      end
    end
  end

  test "requires approval by default and does not mutate", %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")

    assert {:ok, result} = execute(workspace, default_context(workspace))
    assert result.status == :error
    assert result.error.code == "approval_required"
    assert File.read!(path) == "before"
  end

  test "denial has no side effect and separates the summary from operation details", %{
    tmp_dir: workspace
  } do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")
    context = context(workspace, :deny)

    assert {:ok, result} = execute(workspace, context)
    assert result.error.code == "approval_denied"
    assert File.read!(path) == "before"

    assert_received {:approval_request, request}
    assert request.tool == "replace_in_file"
    assert request.target == "sample.txt"
    assert request.risk == :write
    assert request.arguments_summary == "path; expected: 6 bytes; replacement: 5 bytes"
    refute String.contains?(request.arguments_summary, "before")
    refute String.contains?(request.arguments_summary, "after")

    assert Jason.decode!(request.preview) == %{
             "path" => "sample.txt",
             "expected" => "before",
             "replacement" => "after",
             "workspace" => workspace
           }
  end

  test "approved exact replacement changes only the intended occurrence", %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "prefix before suffix")

    assert {:ok, result} = execute(workspace, context(workspace, :allow))
    assert result.status == :success
    assert result.content == "Replaced one occurrence"
    assert File.read!(path) == "prefix after suffix"
  end

  test "ambiguous replacement fails without changing the file", %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before and before")

    assert {:ok, result} = execute(workspace, context(workspace, :allow))
    assert result.error.code == "ambiguous_replacement"
    assert File.read!(path) == "before and before"
  end

  test "mutation queue executes operations sequentially" do
    owner = self()
    first = Task.async(fn -> Queue.run(BlockingOperation, {owner, :first}) end)
    assert_receive {:started, :first}

    second = Task.async(fn -> Queue.run(BlockingOperation, {owner, :second}) end)
    refute_receive {:started, :second}, 25

    send(Process.whereis(Queue), {:continue, :first})
    assert {:ok, "first"} = Task.await(first)
    assert_receive {:started, :second}

    send(Process.whereis(Queue), {:continue, :second})
    assert {:ok, "second"} = Task.await(second)
  end

  test "mutation queue skips work abandoned before it starts" do
    owner = self()
    first = Task.async(fn -> Queue.run(BlockingOperation, {owner, :first}) end)
    assert_receive {:started, :first}

    second = Task.async(fn -> Queue.run(BlockingOperation, {owner, :second}) end)
    await_queued_call()
    Task.shutdown(second, :brutal_kill)

    send(Process.whereis(Queue), {:continue, :first})
    assert {:ok, "first"} = Task.await(first)
    refute_receive {:started, :second}, 25
  end

  defp execute(_workspace, context) do
    {:ok, definition} = ReplaceInFile.definition()
    {:ok, registry} = Registry.new([definition])

    Tool.execute(
      registry,
      %{
        id: "call-1",
        name: "replace_in_file",
        arguments: %{
          "path" => "sample.txt",
          "expected" => "before",
          "replacement" => "after"
        }
      },
      context
    )
  end

  defp default_context(workspace) do
    {:ok, policy} = Policy.new(allowed_risks: [:write])
    {:ok, context} = Context.new(workspace: workspace, policy: policy)
    context
  end

  defp context(workspace, outcome) do
    {:ok, policy} = Policy.new(allowed_risks: [:write])

    {:ok, context} =
      Context.new(
        workspace: workspace,
        policy: policy,
        approval: {ApprovalPolicy, %{owner: self(), outcome: outcome}}
      )

    context
  end

  defp await_queued_call(attempts \\ 100)

  defp await_queued_call(0) do
    flunk("mutation call was not queued")
  end

  defp await_queued_call(attempts) do
    queue = Process.whereis(Queue)

    case Process.info(queue, :message_queue_len) do
      {:message_queue_len, length} when length > 0 ->
        :ok

      _result ->
        Process.sleep(1)
        await_queued_call(attempts - 1)
    end
  end
end
