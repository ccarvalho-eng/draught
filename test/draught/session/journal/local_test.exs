defmodule Draught.Session.Journal.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Session.Journal.Local
  alias Draught.Session.Journal.Local.Configuration
  alias Draught.Session.Journal.Record
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  @moduletag :tmp_dir
  @timestamp ~U[2026-09-07 01:02:03Z]

  test "round trips canonical history and resumes at the next sequence", %{tmp_dir: workspace} do
    configuration = configuration(workspace, "round-trip")
    request = request("inspect")
    tool_call = call("call-1", %{"path" => "private-value"})
    tool_response = response_with_tool(tool_call)
    tool_result = result("private-output")
    final_response = response("done", usage())

    assert {:ok, handle, replay} = Local.open(configuration)
    assert replay.terminal == :empty

    events = [
      {:turn_started, 1, "Elixir.Example.Provider", request},
      {:provider_result, 1, 1, {:ok, tool_response}},
      {:tool_result, 1, 1, tool_result},
      {:provider_result, 1, 2, {:ok, final_response}},
      {:turn_terminal, 1, {:ok, final_response}}
    ]

    handle = append_all(handle, events)
    assert {:ok, ^handle} = Local.checkpoint(handle)
    assert {:ok, resumed, replayed} = Local.open(configuration)

    assert resumed.next_sequence == 6
    assert replayed.next_sequence == 6
    assert replayed.provider == "Elixir.Example.Provider"
    assert replayed.model == "model"
    assert replayed.usage == usage()
    assert replayed.created_at == @timestamp
    assert replayed.updated_at == @timestamp
    assert {:completed, 1, {:ok, ^final_response}} = replayed.terminal

    assert [user, assistant_tool, tool_message, assistant_final] = replayed.messages
    assert user == hd(request.messages)
    assert hd(assistant_tool.tool_calls).arguments == %{}
    assert tool_message.result.content == ""
    assert assistant_final == final_response.message

    journal = File.read!(configuration.paths.journal)
    refute journal =~ "private-value"
    refute journal =~ "private-output"

    assert journal
           |> String.split("\n", trim: true)
           |> Enum.all?(fn line ->
             Jason.decode!(line)["schema_version"] == Record.schema_version()
           end)

    checkpoint =
      configuration.paths.checkpoint
      |> File.read!()
      |> Jason.decode!()

    assert checkpoint["schema_version"] == 1
    assert checkpoint["journal_bytes"] == byte_size(journal)
    temporary_pattern = Path.join(configuration.paths.directory, "checkpoint-*.tmp")
    assert Path.wildcard(temporary_pattern) == []

    {:ok, journal_stat} = File.stat(configuration.paths.journal)
    {:ok, checkpoint_stat} = File.stat(configuration.paths.checkpoint)
    {:ok, directory_stat} = File.stat(configuration.paths.directory)
    assert Bitwise.band(journal_stat.mode, 0o777) == 0o600
    assert Bitwise.band(checkpoint_stat.mode, 0o777) == 0o600
    assert Bitwise.band(directory_stat.mode, 0o777) == 0o700
  end

  test "retention can explicitly preserve canonical tool values", %{tmp_dir: workspace} do
    configuration =
      configuration(workspace, "retained",
        retention: [tool_arguments: :retain, tool_output: :retain]
      )

    request = request("inspect")
    tool_call = call("call-1", %{"path" => "kept-argument"})
    tool_response = response_with_tool(tool_call)
    tool_result = result("kept-output")
    final_response = response("done", nil)

    {:ok, handle, _replay} = Local.open(configuration)

    completed_handle =
      append_all(handle, [
        {:turn_started, 1, "Elixir.Example.Provider", request},
        {:provider_result, 1, 1, {:ok, tool_response}},
        {:tool_result, 1, 1, tool_result},
        {:provider_result, 1, 2, {:ok, final_response}},
        {:turn_terminal, 1, {:ok, final_response}}
      ])

    assert completed_handle.next_sequence == 6
    assert {:ok, replayed} = Local.replay(configuration)

    assistant = Enum.at(replayed.messages, 1)
    first_call = hd(assistant.tool_calls)
    assert first_call.arguments == %{"path" => "kept-argument"}

    assert Enum.at(replayed.messages, 2).result.content == "kept-output"
  end

  test "an incomplete final record fails without changing journal bytes", %{tmp_dir: workspace} do
    configuration = configuration(workspace, "partial")
    {:ok, handle, _replay} = Local.open(configuration)
    event = {:turn_started, 1, "provider", request("one")}
    {:ok, _handle} = Local.append(handle, event)
    :ok = File.write(configuration.paths.journal, "{", [:append])
    before = File.read!(configuration.paths.journal)

    assert {:error, error} = Local.replay(configuration)
    assert error.code == "journal_corrupt"
    assert File.read!(configuration.paths.journal) == before
  end

  test "a newer record schema fails without overwriting source data", %{tmp_dir: workspace} do
    configuration = configuration(workspace, "newer")
    :ok = File.mkdir_p(configuration.paths.directory)

    record = %{
      "data" => %{},
      "recorded_at" => DateTime.to_iso8601(@timestamp),
      "schema_version" => Record.schema_version() + 1,
      "sequence" => 1,
      "type" => "future"
    }

    content = Jason.encode!(record) <> "\n"
    :ok = File.write(configuration.paths.journal, content)

    assert {:error, error} = Local.open(configuration)
    assert error.code == "journal_version_unsupported"
    assert File.read!(configuration.paths.journal) == content
  end

  test "blank records are corruption rather than ignored input", %{tmp_dir: workspace} do
    configuration = configuration(workspace, "blank-record")
    {:ok, handle, _replay} = Local.open(configuration)
    event = {:turn_started, 1, "provider", request("one")}
    {:ok, _handle} = Local.append(handle, event)
    :ok = File.write(configuration.paths.journal, "\n", [:append])
    before = File.read!(configuration.paths.journal)

    assert {:error, error} = Local.replay(configuration)
    assert error.code == "journal_corrupt"
    assert File.read!(configuration.paths.journal) == before
  end

  test "corrupt checkpoints and orphan temporary files do not affect replay", %{
    tmp_dir: workspace
  } do
    configuration = configuration(workspace, "disposable")
    {:ok, handle, _replay} = Local.open(configuration)
    final_response = response("done", nil)

    _handle =
      append_all(handle, [
        {:turn_started, 1, "provider", request("one")},
        {:provider_result, 1, 1, {:ok, final_response}},
        {:turn_terminal, 1, {:ok, final_response}}
      ])

    :ok = File.write(configuration.paths.checkpoint, "not-json")
    temporary = Path.join(configuration.paths.directory, "checkpoint-crash.tmp")
    :ok = File.write(temporary, "partial")

    assert {:ok, replayed} = Local.replay(configuration)
    assert {:completed, 1, {:ok, ^final_response}} = replayed.terminal
  end

  test "validates identifiers before creating storage paths", %{tmp_dir: workspace} do
    assert {:error, error} = Configuration.new(workspace, "../escape")
    assert [%{path: [:session_id]}] = error.violations
    data_directory = Path.join(workspace, ".draught")
    refute File.exists?(data_directory)
  end

  defp configuration(workspace, id, options \\ []) do
    options = Keyword.put(options, :clock, fn -> @timestamp end)
    {:ok, configuration} = Configuration.new(workspace, id, options)
    configuration
  end

  defp append_all(handle, events) do
    Enum.reduce(events, handle, fn event, current ->
      {:ok, updated} = Local.append(current, event)
      updated
    end)
  end

  defp request(content) do
    {:ok, user} = Conversation.user(content)
    {:ok, request} = Request.new(model: "model", messages: [user])
    request
  end

  defp call(id, arguments) do
    {:ok, call} = Call.new(id: id, name: "read_file", arguments: arguments)
    call
  end

  defp result(content) do
    {:ok, result} =
      Result.new(call_id: "call-1", name: "read_file", content: content, status: :success)

    result
  end

  defp response_with_tool(call) do
    {:ok, assistant} = Conversation.assistant(tool_calls: [call])
    {:ok, response} = Response.new(message: assistant, finish_reason: :tool_calls)
    response
  end

  defp response(content, usage) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop, usage: usage)
    response
  end

  defp usage do
    {:ok, usage} =
      Usage.new(
        input_tokens: 10,
        output_tokens: 5,
        cached_tokens: 2,
        reasoning_tokens: 1
      )

    usage
  end
end
