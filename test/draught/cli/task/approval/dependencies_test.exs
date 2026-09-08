defmodule Draught.CLI.Task.Approval.DependenciesTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Named
  alias Draught.CLI.Task.Setup
  alias Draught.CLI.Task.Stream
  alias Draught.Conversation
  alias Draught.Conversation.Message.Tool
  alias Draught.Provider.Response
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Validation.Error

  @moduletag :tmp_dir

  defmodule Policy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(request, {owner, outcome, marker}) do
      send(owner, {:approval_requested, marker, request})
      Decision.new(outcome: outcome)
    end
  end

  defmodule Provider do
    @behaviour Draught.Provider

    alias Draught.Provider.Capabilities
    alias Draught.Tool.Call

    @impl Draught.Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, streaming: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(request, configuration) do
      request.messages
      |> Enum.reverse()
      |> respond(configuration)
    end

    @impl Draught.Provider
    def stream(request, configuration, _sink) do
      complete(request, configuration)
    end

    defp respond([%Tool{result: result} | _history], configuration) do
      send(configuration.owner, {:tool_result, result})
      {:ok, message} = Conversation.assistant(content: "done")
      Response.new(message: message, finish_reason: :stop)
    end

    defp respond([user | _history], configuration) do
      {:ok, call} =
        Call.new(
          id: "edit",
          name: "replace_in_file",
          arguments: %{
            "path" => "sample.txt",
            "expected" => configuration.expected,
            "replacement" => user.content.text
          }
        )

      {:ok, message} = Conversation.assistant(tool_calls: [call])
      Response.new(message: message, finish_reason: :tool_calls)
    end
  end

  defmodule ProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    alias Draught.CLI.Task.Provider.Selection

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, configuration) do
      Selection.new({Provider, configuration}, "free-model")
    end
  end

  setup %{tmp_dir: workspace} do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")

    configuration = %Configuration{
      profile: "test",
      provider: :ollama,
      base_url: "http://localhost:11434",
      model: "free-model",
      web: false,
      web_search: false,
      risk: :ask,
      origins: %{}
    }

    %{configuration: configuration, path: path, workspace: workspace}
  end

  test "validates approval adapters without reflecting their configuration" do
    assert {:ok, default} = Dependencies.new([], nil)
    assert Map.fetch!(default, :approval) == nil

    assert {:ok, explicit_default} = Dependencies.new([approval: nil], nil)
    assert Map.fetch!(explicit_default, :approval) == nil

    for policy <- [{String, "private-value"}, :invalid, {"module", nil}] do
      assert {:error, %Error{violations: [violation]}} =
               Dependencies.new([approval: policy], nil)

      assert violation.path == [:approval]
      refute inspect(violation) =~ "private-value"
    end
  end

  test "retains default approval when no dependency is provided", context do
    assert {:ok, preparation} =
             Setup.prepare("after", context.configuration, context.workspace, dependencies(nil))

    assert preparation.runner.tool_context.approval == {Default, nil}
  end

  test "injected policy takes precedence over options while absent policy preserves them",
       context do
    {:ok, injected} =
      Draught.CLI.Dependencies.new(task: [approval: {Policy, {self(), :deny, :explicit}}])

    assert injected.task.approval == {Policy, {self(), :deny, :explicit}}
    explicit_option = {Policy, {self(), :allow, :option}}

    assert {:ok, preparation} =
             Setup.prepare("after", context.configuration, context.workspace, dependencies(:deny),
               approval: explicit_option
             )

    assert preparation.runner.tool_context.approval == dependencies(:deny).approval

    assert {:ok, fallback} =
             Setup.prepare("after", context.configuration, context.workspace, dependencies(nil),
               approval: explicit_option
             )

    assert fallback.runner.tool_context.approval == explicit_option
    refute_receive {:approval_requested, _marker, _request}
  end

  test "runs an approved anonymous edit through the injected policy", context do
    assert {:ok, %Response{}} =
             Task.run("after", context.configuration, context.workspace, dependencies(:allow))

    assert_receive {:approval_requested, :allow, request}
    assert request.tool == "replace_in_file"
    assert request.target == "sample.txt"
    assert_receive {:tool_result, %{status: :success}}
    assert File.read!(context.path) == "after"
    refute_receive {:approval_requested, _marker, _request}
  end

  test "an injected approval cannot expand the configured risk allowlist", context do
    configuration = %{context.configuration | risk: :deny}

    assert {:ok, %Response{}} =
             Task.run("after", configuration, context.workspace, dependencies(:allow))

    assert_receive {:tool_result, %{error: %{code: "tool_risk_denied"}}}
    refute_receive {:approval_requested, _marker, _request}
    assert File.read!(context.path) == "before"
  end

  test "allow mode retains its default but an explicit policy can still deny", context do
    configuration = %{context.configuration | risk: :allow}

    assert {:ok, %Response{}} =
             Task.run("after", configuration, context.workspace, dependencies(:deny))

    assert_receive {:approval_requested, :deny, _request}
    assert_receive {:tool_result, %{error: %{code: "approval_denied"}}}
    assert File.read!(context.path) == "before"

    assert {:ok, %Response{}} =
             Task.run("after", configuration, context.workspace, dependencies(nil))

    assert_receive {:tool_result, %{status: :success}}
    refute_receive {:approval_requested, _marker, _request}
    assert File.read!(context.path) == "after"
  end

  test "named resume uses the new policy and never restores an earlier grant", context do
    environment = %{"XDG_STATE_HOME" => Path.join(context.tmp_dir, "state")}

    assert {:ok, %Response{}} =
             named(:create, "after", context, environment, dependencies(:allow))

    assert_receive {:approval_requested, :allow, _request}
    assert_receive {:tool_result, %{status: :success}}

    assert {:ok, %Response{}} =
             named(:resume, "again", context, environment, dependencies(:deny, "after"))

    assert_receive {:approval_requested, :deny, _request}
    assert_receive {:tool_result, %{error: %{code: "approval_denied"}}}

    assert {:ok, %Response{}} =
             named(:resume, "again", context, environment, dependencies(nil, "after"))

    assert_receive {:tool_result, %{error: %{code: "approval_required"}}}
    refute_receive {:approval_requested, _marker, _request}
    assert File.read!(context.path) == "after"
  end

  defp named(operation, prompt, context, environment, dependencies) do
    {result, _stream} =
      Named.run_observed(
        operation,
        "approval-dependencies",
        prompt,
        context.configuration,
        context.workspace,
        environment,
        dependencies,
        Stream.silent()
      )

    result
  end

  defp dependencies(outcome, expected \\ "before") do
    provider = {ProviderFactory, %{owner: self(), expected: expected}}
    attributes = approval_attributes(outcome, provider)
    {:ok, dependencies} = Dependencies.new(attributes, nil)
    dependencies
  end

  defp approval_attributes(nil, provider) do
    [provider: provider]
  end

  defp approval_attributes(outcome, provider) do
    [provider: provider, approval: {Policy, {self(), outcome, outcome}}]
  end
end
