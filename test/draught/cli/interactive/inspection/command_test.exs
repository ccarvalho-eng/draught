defmodule Draught.CLI.Interactive.Inspection.CommandTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Inspection.Command
  alias Draught.CLI.Interactive.State
  alias Draught.Tool.Approval.Decision

  defmodule ApprovalPolicy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(_request, _configuration) do
      Decision.new(outcome: :deny)
    end
  end

  test "lists the effective built-in catalog without executor metadata" do
    assert {:ok, {:tools, catalog}} =
             Command.run(:tools, state(), configuration(), dependencies())

    assert Enum.map(catalog.entries, & &1.name) == [
             "read_file",
             "list_directory",
             "search_workspace",
             "replace_in_file",
             "run_command"
           ]

    assert Enum.all?(catalog.entries, fn entry ->
             entry
             |> Map.keys()
             |> Enum.sort()
             |> Kernel.==([:description, :name, :risk])
           end)

    refute catalog.web_fetch
    refute catalog.web_search
  end

  test "includes only explicitly enabled web tools" do
    configuration =
      configuration(
        web: true,
        web_search: true,
        web_search_url: "http://127.0.0.1:8080/search"
      )

    assert {:ok, {:tools, catalog}} =
             Command.run(
               :tools,
               state(web: true, web_search: true),
               configuration,
               dependencies()
             )

    assert Enum.map(catalog.entries, & &1.name) == [
             "read_file",
             "list_directory",
             "search_workspace",
             "replace_in_file",
             "run_command",
             "web_search",
             "web_fetch"
           ]

    assert catalog.web_fetch
    assert catalog.web_search
  end

  test "reports risk admission and default approval behavior" do
    assert {:ok, {:permissions, ask}} =
             Command.run(:permissions, state(), configuration(risk: :ask), dependencies())

    assert ask.admitted_risks == [:read, :write, :execute, :network]
    assert ask.approval == :effectful

    assert {:ok, {:permissions, deny}} =
             Command.run(:permissions, state(), configuration(risk: :deny), dependencies())

    assert deny.admitted_risks == [:read]
    assert deny.approval == :automatic

    assert {:ok, {:permissions, allow}} =
             Command.run(:permissions, state(), configuration(risk: :allow), dependencies())

    assert allow.admitted_risks == [:read, :write, :execute, :network]
    assert allow.approval == :automatic
  end

  test "identifies an explicitly injected application approval policy" do
    {:ok, dependencies} =
      Dependencies.new(task: [approval: {ApprovalPolicy, nil}])

    assert {:ok, {:permissions, permissions}} =
             Command.run(:permissions, state(), configuration(), dependencies)

    assert permissions.approval == :application_policy
  end

  test "rejects commands outside the inspection context" do
    assert Command.run(:status, state(), configuration(), dependencies()) ==
             {:error, :invalid_command}
  end

  defp configuration(overrides \\ []) do
    defaults = %{
      base_url: "http://127.0.0.1:11434",
      credential: nil,
      model: "qwen3",
      origins: %{},
      profile: "ollama",
      provider: :ollama,
      risk: :ask,
      web: false,
      web_search: false,
      web_search_url: nil
    }

    struct!(Configuration, Map.merge(defaults, Map.new(overrides)))
  end

  defp dependencies do
    {:ok, dependencies} = Dependencies.new()
    dependencies
  end

  defp state(overrides \\ []) do
    attributes =
      Keyword.merge(
        [
          session_id: "session-01",
          provider: "ollama",
          model: "qwen3",
          workspace: "/workspace",
          web: false
        ],
        overrides
      )

    {:ok, state} = State.new(attributes)
    state
  end
end
