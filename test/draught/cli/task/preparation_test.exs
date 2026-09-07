defmodule Draught.CLI.Task.PreparationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Approval.Fixed
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.User
  alias Draught.Provider.Fake
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Tool.Registry
  alias Draught.Tool.Risk

  test "builds one bounded agent turn from explicit provider and workspace inputs" do
    assert {:ok, provider} = Fake.new()
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")

    assert {:ok, preparation} =
             Preparation.new("Inspect the project", selection, "/workspace", risk: :ask)

    assert [%System{}, %User{}] = preparation.request.messages
    assert preparation.request.model == "free-model"

    assert Registry.names(preparation.runner.registry) == [
             "read_file",
             "list_directory",
             "search_workspace",
             "replace_in_file",
             "run_command"
           ]

    assert preparation.runner.tool_context.policy.allowed_risks == Risk.classes()
    assert {Default, nil} = preparation.runner.tool_context.approval
    assert preparation.runner.tool_context.web.policy.search == false
    assert preparation.runner.tool_context.web.policy.fetch == false
    assert preparation.session_options == [journal: false, turn_timeout_ms: 600_000]
  end

  test "maps deny and allow risk modes without an implicit approval prompt" do
    assert {:ok, provider} = Fake.new()
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")

    assert {:ok, denied} = Preparation.new("Inspect", selection, "/workspace", risk: :deny)
    assert denied.runner.tool_context.policy.allowed_risks == [:read]
    assert {Default, nil} = denied.runner.tool_context.approval

    assert {:ok, allowed} = Preparation.new("Edit", selection, "/workspace", risk: :allow)
    assert allowed.runner.tool_context.policy.allowed_risks == Risk.classes()
    assert {Fixed, :allow} = allowed.runner.tool_context.approval
  end

  test "rejects enabled web execution until a complete capability is injected" do
    assert {:ok, provider} = Fake.new()
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")

    assert {:error, error} =
             Preparation.new("Search", selection, "/workspace", web: true)

    violation = hd(error.violations)
    assert violation.path == [:web]
  end
end
