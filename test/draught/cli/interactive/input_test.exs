defmodule Draught.CLI.Interactive.InputTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Input

  test "parses prompts and ignores blank input" do
    assert Input.parse("fix the tests") == {:ok, {:prompt, "fix the tests"}}
    assert Input.parse("  fix the tests  ") == {:ok, {:prompt, "fix the tests"}}
    assert Input.parse("   \n") == {:ok, :empty}
  end

  test "parses commands without forwarding them as prompts" do
    assert Input.parse("/help") == {:ok, {:command, :help, nil}}
    assert Input.parse("/status") == {:ok, {:command, :status, nil}}
    assert Input.parse("/exit") == {:ok, {:command, :exit, nil}}

    assert Input.parse("/resume session-01") ==
             {:ok, {:command, :resume, "session-01"}}

    assert Input.parse("/new review") == {:ok, {:command, :new, "review"}}
    assert Input.parse("/new") == {:ok, {:command, :new, nil}}
    assert Input.parse("/resume") == {:ok, {:command, :resume, nil}}
    assert Input.parse("/restore") == {:ok, {:command, :restore, nil}}
    assert Input.parse("/") == {:ok, {:command, :palette, nil}}
  end

  test "parses direct commands and file searches as explicit actions" do
    assert Input.parse("!mix test") == {:ok, {:shell, "mix test"}}
    assert Input.parse("@lib/draught") == {:ok, {:file, "lib/draught"}}
  end

  test "rejects unknown commands, missing arguments, and invalid input" do
    assert Input.parse("/unknown") == {:error, :unknown_command}
    assert Input.parse("/rename") == {:error, :argument_required}
    assert Input.parse("/exit now") == {:error, :unexpected_argument}
    assert Input.parse(:invalid) == {:error, :invalid_input}
  end

  test "bounds interactive input" do
    oversized = String.duplicate("x", Input.maximum_bytes() + 1)

    assert Input.parse(oversized) == {:error, :input_too_large}
  end
end
