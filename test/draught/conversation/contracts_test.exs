defmodule Draught.Conversation.ContractsTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Conversation.Content
  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.Tool
  alias Draught.Conversation.Message.User
  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Result
  alias Draught.Validation.Error

  test "constructs and identifies typed content parts" do
    assert {:ok, %Text{text: "visible"} = text} = Content.new(type: :text, text: "visible")

    assert {:ok, %Reasoning{text: "private"} = reasoning} =
             Content.new(type: "reasoning", text: "private")

    assert Content.type(text) == :text
    assert Content.type(reasoning) == :reasoning
    assert {:ok, ^text} = Content.text(text)
    assert {:error, %Error{}} = Content.new(type: :image, text: "unsupported")
    assert {:error, %Error{}} = Content.text(reasoning)
  end

  test "constructs system and user messages through convenience functions" do
    assert {:ok, %System{content: %Text{text: "Be precise"}} = system} =
             Conversation.system("Be precise")

    assert {:ok, %User{content: %Text{text: "Hello"}} = user} = Conversation.user("Hello")
    assert Message.role(system) == :system
    assert Message.role(user) == :user
  end

  test "constructs assistant messages with ordered text, reasoning, and calls" do
    assert {:ok, call} = Call.new(id: "call-1", name: "read_file", arguments: %{"path" => "a"})

    assert {:ok, assistant} =
             Conversation.assistant(
               content: [
                 %{type: :reasoning, text: "inspect"},
                 %{type: :text, text: "I will read it"}
               ],
               tool_calls: [call]
             )

    assert %Assistant{} = assistant
    assert Enum.map(assistant.content, &Content.type/1) == [:reasoning, :text]
    assert assistant.tool_calls == [call]
    assert Message.role(assistant) == :assistant
  end

  test "supports the assistant string shortcuts" do
    assert {:ok, assistant} = Assistant.new(content: "answer", reasoning: "thought")
    assert Enum.map(assistant.content, & &1.text) == ["answer", "thought"]
  end

  test "rejects empty assistants, malformed content, and duplicate call IDs" do
    assert {:error, %Error{}} = Assistant.new([])
    assert {:error, %Error{}} = Assistant.new(content: 42)
    assert {:error, %Error{}} = Assistant.new(content: [%{type: :text, text: ""}])

    calls = [
      %{id: "same", name: "one", arguments: %{}},
      %{id: "same", name: "two", arguments: %{}}
    ]

    assert {:error, %Error{}} = Assistant.new(tool_calls: calls)
  end

  test "constructs successful and failed tool messages" do
    assert {:ok, success} =
             Conversation.tool(call_id: "call-1", name: "read_file", content: "contents")

    assert %Tool{result: %Result{status: :success}} = success
    assert Message.role(success) == :tool

    assert {:ok, error} = Normalized.new(:tool, "failed", "tool failed")

    assert {:ok, failed} =
             Conversation.tool(
               call_id: "call-2",
               name: "write_file",
               content: "",
               status: :error,
               error: error
             )

    assert failed.result.error == error
  end

  test "message facade dispatches all external roles and prefixes errors" do
    assert {:ok, %System{}} = Message.new(role: "system", content: "system")
    assert {:ok, %User{}} = Message.new(role: :user, content: "user")
    assert {:ok, %Assistant{}} = Message.new(role: :assistant, content: "assistant")

    assert {:ok, %Tool{}} =
             Message.new(
               role: :tool,
               result: %{call_id: "call-1", name: "read_file", content: "ok"}
             )

    assert {:error, %Error{violations: [%{path: [:assistant]}]}} =
             Message.new(role: :assistant)

    assert {:error, %Error{}} = Message.new(role: :unknown, content: "no")
    assert {:error, %Error{}} = Message.new(role: :user, content: "ok", tool_calls: [])
  end

  test "revalidates manually constructed nested structs" do
    invalid_text = %Text{text: ""}
    invalid_result = %Result{call_id: "", name: "bad name", content: "", status: :success}

    assert {:error, %Error{}} = System.new(content: invalid_text)
    assert {:error, %Error{}} = Tool.new(invalid_result)
  end

  test "revalidates every message variant and direct tool results" do
    assert {:ok, system} = Conversation.system("system")
    assert {:ok, user} = Conversation.user("user")
    assert {:ok, assistant} = Conversation.assistant(content: "assistant")
    assert {:ok, result} = Result.new(call_id: "call-1", name: "read_file", content: "ok")
    assert {:ok, tool} = Conversation.tool(result)

    Enum.each([system, user, assistant, tool], fn message ->
      assert {:ok, ^message} = Message.validate(message)
    end)

    assert {:ok, %Tool{result: ^result}} = Tool.new(result: result)
    assert {:error, %Error{}} = Tool.new(result: :invalid)
    assert {:error, %Error{}} = Message.validate(:invalid)
  end

  test "keeps the content-filtered assistant placeholder response-scoped" do
    filtered = Assistant.filtered()

    assert {:error, %Error{}} = Message.validate(filtered)
  end

  test "rejects malformed assistant shortcuts, structs, and tool-call collections" do
    assert {:error, %Error{}} = Assistant.new(content: "")
    assert {:error, %Error{}} = Assistant.new(reasoning: "")
    assert {:error, %Error{}} = Assistant.new(content: [%Text{text: ""}])
    assert {:error, %Error{}} = Assistant.new(content: [%Reasoning{text: ""}])
    assert {:error, %Error{}} = Assistant.new(content: [42])
    assert {:error, %Error{}} = Assistant.new(tool_calls: :invalid)
    assert {:error, %Error{}} = Assistant.new(tool_calls: [42])

    invalid_call = %Call{id: "", name: "bad name", arguments: %{}}
    assert {:error, %Error{}} = Assistant.new(tool_calls: [invalid_call])
    assert {:error, %Error{}} = Assistant.new(tool_calls: [%{id: "", name: "bad"}])
  end
end
