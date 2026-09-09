defmodule Draught.CLI.Task.OneShot.ApprovalTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Interactive
  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Approval.Prompt.Pending
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.OneShot.Approval
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.CLI.Task.Stream
  alias Draught.Conversation
  alias Draught.Conversation.Message.Tool
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Response
  alias Draught.Tool.Call

  @receive_timeout 1_000
  @approval_start_timeout 5_000
  @tool_timeout 1_000
  @moduletag :tmp_dir

  defmodule Provider do
    @moduledoc false

    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(request, owner) do
      request.messages
      |> Enum.reverse()
      |> respond(owner)
    end

    @impl Draught.Provider
    def stream(_request, _configuration, _sink) do
      {:error, :not_used}
    end

    defp respond([%Tool{result: result} | _history], owner) do
      send(owner, {:approval_result, result})
      {:ok, assistant} = Conversation.assistant(content: "continued safely")
      Response.new(message: assistant, finish_reason: :stop)
    end

    defp respond(_messages, _owner) do
      {:ok, call} =
        Call.new(
          id: "edit-1",
          name: "replace_in_file",
          arguments: %{
            "path" => "sample.txt",
            "expected" => "before",
            "replacement" => "after"
          }
        )

      {:ok, assistant} = Conversation.assistant(tool_calls: [call])
      Response.new(message: assistant, finish_reason: :tool_calls)
    end
  end

  defmodule SystemAdapter do
    @moduledoc false

    @spec columns(term()) :: {:ok, 80}
    def columns(_configuration) do
      {:ok, 80}
    end

    @spec tty?(atom(), term()) :: true
    def tty?(_stream, _configuration) do
      true
    end

    @spec write(atom(), iodata(), pid()) :: :ok
    def write(stream, content, owner) do
      send(owner, {:approval_output, stream, IO.iodata_to_binary(content)})
      :ok
    end
  end

  defmodule Terminal do
    @moduledoc false

    @spec request_line(pid()) :: {:ok, reference()}
    def request_line(owner) do
      reference = make_ref()
      send(owner, {:approval_input_requested, self(), reference})
      {:ok, reference}
    end

    @spec cancel_read(reference(), pid()) :: :ok
    def cancel_read(reference, owner) do
      send(owner, {:approval_input_cancelled, reference})
      :ok
    end
  end

  test "a stopped requester keeps terminal input until the answer is consumed" do
    scope = make_ref()
    decision = make_ref()
    input = make_ref()
    requester = spawn(fn -> :ok end)
    monitor = Process.monitor(requester)
    assert_receive {:DOWN, ^monitor, :process, ^requester, _reason}
    pending = Pending.new(requester, decision, input)
    prompt = %{Prompt.new(scope, {Terminal, self()}) | pending: pending}
    stream = %{Stream.silent() | approval: prompt}

    waiting = Approval.requester_stopped(stream)
    assert waiting.approval.pending.input == input
    assert waiting.approval.pending.monitor == nil

    assert {:ok, resolved} = Approval.reply(waiting, {:ok, "y\n"})
    assert resolved.approval.pending == nil
    refute_receive {:approval_input_cancelled, ^input}
  end

  test "human approval time is excluded from tool and turn deadlines", %{
    tmp_dir: workspace
  } do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")
    owner = self()

    task =
      Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, fn ->
        scope = make_ref()
        approval = {Interactive, %{owner: self(), scope: scope}}
        {:ok, selection} = Selection.new({Provider, owner}, "free-model")

        {:ok, preparation} =
          Preparation.new("edit the file", selection, workspace,
            approval: approval,
            limits: [tool_timeout_ms: @tool_timeout],
            risk: :ask
          )

        preparation = %{preparation | session_options: [journal: false, turn_timeout_ms: 10]}

        stream =
          Stream.new(:text, {SystemAdapter, owner},
            approval: Prompt.new(scope, {Terminal, owner}),
            color: :never
          )

        OneShot.run_observed("delayed-approval-session", preparation, stream)
      end)

    assert_receive {:approval_input_requested, caller, reference}, @approval_start_timeout
    task_reference = task.ref
    refute_receive {^task_reference, _result}, @tool_timeout + 100

    send(caller, {:draught_terminal_input, reference, {:ok, "y\n"}})

    assert {{:ok, %Response{}}, _stream} = Task.await(task)
    assert_receive {:approval_result, %{status: :success}}, @receive_timeout
    assert File.read!(path) == "after"
    refute_receive {:approval_input_cancelled, ^reference}
  end
end
