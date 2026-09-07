defmodule Draught.CLI.UI do
  @moduledoc """
  Provides the project-owned rendering facade for the interactive terminal.

  Core command and session modules pass display-safe values through this
  boundary without depending on Owl or terminal control behavior.
  """

  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Output.Sanitizer
  alias Draught.CLI.UI.Owl

  @doc "Renders the initial bounded session card for a known terminal width."
  @spec banner(State.t(), pos_integer(), boolean()) :: iodata()
  def banner(%State{} = state, width, styled?)
      when is_integer(width) and width > 0 and is_boolean(styled?) do
    Owl.banner(state, width, styled?)
  end

  @doc "Renders the interactive command index."
  @spec help() :: iodata()
  def help do
    [
      "Available commands:\n",
      "  /help          Show commands and input forms\n",
      "  /status        Show the active session configuration\n",
      "  /doctor        Run diagnostics\n",
      "  /exit          Close the interactive session\n",
      "\nReserved commands:\n",
      "  /model         Inspect or select a model\n",
      "  /provider      Inspect or select a provider\n",
      "  /permissions   Inspect the approval policy\n",
      "  /web           Inspect web capability state\n",
      "  /sessions      List and select sessions\n",
      "  /resume ID     Resume a session\n",
      "  /new [NAME]    Start a session\n",
      "  /rename NAME   Change the session display name\n",
      "  /archive [ID]  Archive a session\n",
      "  /context       Show retained context sources\n",
      "  /compact       Create a summary checkpoint\n",
      "  /diff          Show workspace changes\n",
      "  /review        Review workspace changes\n",
      "  /tools         Show available tools and risk classes\n",
      "  /details       Toggle bounded execution metadata\n",
      "\nInput forms:\n",
      "  @QUERY         Reserved for workspace file selection\n",
      "  !COMMAND       Reserved for confined direct commands\n"
    ]
  end

  @doc "Renders the active session configuration without credential material."
  @spec status(State.t()) :: iodata()
  def status(%State{} = state) do
    [
      "Session status\n",
      "  ID: ",
      safe(state.session_id),
      "\n  Provider: ",
      safe(state.provider),
      "\n  Model: ",
      safe(state.model),
      "\n  Workspace: ",
      safe(state.workspace),
      "\n  Web: ",
      web(state.web),
      "\n  Activity: ",
      Atom.to_string(state.phase),
      "\n"
    ]
  end

  @doc "Renders the fixed interactive input prompt."
  @spec prompt() :: iodata()
  def prompt do
    "> "
  end

  @doc "Renders a bounded input failure without reflecting rejected input."
  @spec input_error(atom()) :: iodata()
  def input_error(:argument_required) do
    "That command requires an argument. Run /help for usage.\n"
  end

  def input_error(:input_too_large) do
    "Input exceeds the interactive byte limit.\n"
  end

  def input_error(:unexpected_argument) do
    "That command does not accept an argument. Run /help for usage.\n"
  end

  def input_error(_reason) do
    "Unknown interactive command. Run /help to list commands.\n"
  end

  @doc "Renders a command that is known but not active in the current slice."
  @spec unavailable_command(atom()) :: iodata()
  def unavailable_command(command) when is_atom(command) do
    ["/", Atom.to_string(command), " is not available yet.\n"]
  end

  @doc "Renders the stable final session identifier record."
  @spec session_closed(String.t()) :: iodata()
  def session_closed(identifier) when is_binary(identifier) do
    ["Session ID: ", safe(identifier), "\n"]
  end

  @doc "Renders a safe interactive startup failure."
  @spec startup_error(:jsonl | :not_a_terminal) :: iodata()
  def startup_error(:jsonl) do
    "Interactive mode does not support JSON Lines output. Pass a task prompt instead.\n"
  end

  def startup_error(:not_a_terminal) do
    "Interactive mode requires a terminal. Pass a task prompt for headless execution.\n"
  end

  @doc "Renders an input-device failure without terminal implementation details."
  @spec terminal_error() :: iodata()
  def terminal_error do
    "Interactive input is unavailable.\n"
  end

  defp safe(value) do
    Sanitizer.text(value, 2_048)
  end

  defp web(true) do
    "enabled"
  end

  defp web(false) do
    "disabled"
  end
end
