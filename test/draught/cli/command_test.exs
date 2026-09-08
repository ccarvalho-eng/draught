defmodule Draught.CLI.CommandTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Command
  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Command.Specification

  test "parses the empty invocation as interactive" do
    assert Command.parse([]) == {:ok, %Invocation{command: :interactive}}
    assert Command.parse(["interactive"]) == {:ok, %Invocation{command: :interactive}}
  end

  test "parses a root task and its typed options" do
    arguments = [
      "--provider",
      "ollama",
      "--model",
      "qwen3",
      "--base-url",
      "http://localhost:11434",
      "--session",
      "review",
      "--web",
      "--web-search",
      "--web-search-url",
      "https://search.example.test/search",
      "--output",
      "jsonl",
      "--color",
      "never",
      "--diagnostics",
      "fix",
      "the tests"
    ]

    assert {:ok, invocation} = Command.parse(arguments)
    assert invocation.command == :task
    assert invocation.prompt == "fix the tests"
    assert invocation.provider == "ollama"
    assert invocation.model == "qwen3"
    assert invocation.base_url == "http://localhost:11434"
    assert invocation.session == "review"
    assert invocation.web == :enabled
    assert invocation.web_search == :enabled
    assert invocation.web_search_url == "https://search.example.test/search"
    assert invocation.output == :jsonl
    assert invocation.color == :never
    assert invocation.diagnostics
  end

  test "parses resume and explicit disabled boolean settings" do
    assert {:ok, invocation} =
             Command.parse([
               "--resume",
               "review",
               "--no-web",
               "--no-web-search",
               "--no-diagnostics"
             ])

    assert invocation.command == :interactive
    assert invocation.resume == "review"
    assert invocation.web == :disabled
    assert invocation.web_search == :disabled
    refute invocation.diagnostics
  end

  test "parses doctor, help, version, and their aliases" do
    assert {:ok, %Invocation{command: :doctor}} = Command.parse(["doctor"])
    assert {:ok, %Invocation{command: :help}} = Command.parse(["help"])
    assert {:ok, %Invocation{command: :help}} = Command.parse(["-h"])
    assert {:ok, %Invocation{command: :version}} = Command.parse(["version"])
    assert {:ok, %Invocation{command: :version}} = Command.parse(["-v"])
  end

  test "honors the option terminator for command-shaped task text" do
    assert {:ok, invocation} = Command.parse(["--", "doctor", "--web"])
    assert invocation.command == :task
    assert invocation.prompt == "doctor --web"
    assert invocation.web == :inherit
  end

  test "rejects unknown, invalid, and repeated options" do
    assert {:error, %Error{code: :unknown_option}} = Command.parse(["--unknown"])
    assert {:error, %Error{code: :invalid_option}} = Command.parse(["--provider"])
    assert {:error, %Error{code: :invalid_option}} = Command.parse(["--no-help"])

    assert {:error, %Error{code: :duplicate_option}} =
             Command.parse(["--model", "one", "--model", "two"])

    assert {:error, %Error{code: :invalid_option_value}} =
             Command.parse(["--output", "json"])
  end

  test "rejects conflicting command intent and session selection" do
    assert {:error, %Error{code: :conflicting_options}} =
             Command.parse(["--help", "--version"])

    assert {:error, %Error{code: :conflicting_options}} =
             Command.parse(["--session", "new", "--resume", "old"])

    assert {:error, %Error{code: :unexpected_argument}} =
             Command.parse(["doctor", "extra"])

    assert {:error, %Error{code: :conflicting_options}} =
             Command.parse(["version", "--provider", "ollama"])
  end

  test "rejects invalid raw argument shapes and display-control option values" do
    assert {:error, %Error{code: :invalid_argument}} = Command.parse(:invalid)
    assert {:error, %Error{code: :argument_too_large}} = Command.parse([123])
    assert {:error, %Error{code: :invalid_argument}} = Command.parse([""])

    assert {:error, %Error{code: :invalid_option_value}} =
             Command.parse(["--model", "hidden\nmodel"])
  end

  test "bounds raw arguments, combined input, and the joined task prompt" do
    limits = Specification.limits()
    too_many_arguments = List.duplicate("x", limits.arguments + 1)
    oversized_argument = String.duplicate("x", limits.argument_bytes + 1)
    prompt_piece = String.duplicate("x", 1_000)

    assert {:error, %Error{code: :too_many_arguments}} =
             Command.parse(too_many_arguments)

    assert {:error, %Error{code: :argument_too_large}} =
             Command.parse([oversized_argument])

    prompt_arguments = List.duplicate(prompt_piece, 66)
    assert {:error, %Error{code: :prompt_too_large}} = Command.parse(prompt_arguments)
  end

  test "exposes immutable help and loaded version data" do
    help = Command.help()
    version = Command.version()

    assert help.name == "draught"
    assert Enum.any?(help.options, &(&1.key == :provider))
    assert Enum.any?(help.commands, &(&1.command == :doctor))
    assert version.name == "draught"
    assert version.version == to_string(Application.spec(:draught, :vsn))
  end

  test "keeps exit status values stable and unique" do
    assert ExitStatus.all() == %{
             success: 0,
             usage: 2,
             provider: 3,
             execution: 4,
             session: 5,
             internal: 70,
             interrupted: 130
           }

    assert ExitStatus.value(:success) == 0
    assert ExitStatus.value(:interrupted) == 130
    exit_values = Map.values(ExitStatus.all())
    assert Enum.uniq(exit_values) == exit_values
  end
end
