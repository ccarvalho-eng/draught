defmodule Draught.CLI.UI do
  @moduledoc """
  Provides the project-owned rendering facade for the interactive terminal.

  Core command and session modules pass display-safe values through this
  boundary without depending on Owl or terminal control behavior.
  """

  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.UI.Owl
  alias Draught.CLI.UI.SafeLine
  alias Draught.Error.Normalized

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
      "  /sessions      List sessions in this workspace\n",
      "  /resume [REF]  Select an active session by number, ID, or name\n",
      "  /new [ID]      Start a fresh session\n",
      "  /rename NAME   Change the session display name\n",
      "  /archive [ID]  Archive a session\n",
      "  /restore [ID]  Restore an archived session\n",
      "  /model [REF]   List or select a model by number or exact name\n",
      "  /exit          Close the interactive session\n",
      "\nReserved commands:\n",
      "  /provider      Inspect or select a provider\n",
      "  /permissions   Inspect the approval policy\n",
      "  /web           Inspect web capability state\n",
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
      "\n  Name: ",
      safe(state.session_label),
      "\n  Provider: ",
      safe(state.provider),
      "\n  Model: ",
      model(state.model),
      "\n  Workspace: ",
      safe(state.workspace),
      "\n  Web: ",
      web(state.web),
      "\n  Activity: ",
      Atom.to_string(state.phase),
      "\n"
    ]
  end

  @doc "Renders a bounded line-mode input boundary without cursor movement or speaker names."
  @spec input_area(:open | :close, pos_integer(), boolean()) :: iodata()
  def input_area(phase, width, styled? \\ false)
      when phase in [:open, :close] and is_integer(width) and width > 0 and is_boolean(styled?) do
    Owl.input_area(phase, width, styled?)
  end

  @doc "Renders the fixed tool-activity label with an explicit terminal styling decision."
  @spec tool_label(boolean()) :: iodata()
  def tool_label(styled?) when is_boolean(styled?) do
    Owl.tool_label(styled?)
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

  @doc "Renders a bounded compatible-model list with its current selection."
  @spec models([String.t()], String.t() | nil) :: iodata()
  def models(models, current_model) do
    ["Compatible models:\n", model_lines(models, current_model)]
  end

  @doc "Renders a completed interactive model selection."
  @spec model_selected(String.t()) :: iodata()
  def model_selected(selected_model) do
    ["Selected model ", safe(selected_model), ".\n"]
  end

  @doc "Renders a bounded model command failure and safe next action."
  @spec model_error(term()) :: iodata()
  def model_error(%Normalized{} = error) do
    ["Model command failed (", safe(error.code), "): ", safe(error.message), hint(error.hint)]
  end

  def model_error(:model_required) do
    "Select a model with /model before starting a task.\n"
  end

  def model_error(:persisted_model) do
    "The model is fixed for this persisted session. Run /new before selecting another model.\n"
  end

  def model_error(:not_found) do
    "Model was not found. Run /model to inspect compatible models.\n"
  end

  def model_error(:model_catalog_unavailable) do
    "This provider does not expose a compatible-model catalog. Select an exact model name.\n"
  end

  def model_error(:model_list_required) do
    "Run /model before selecting a model by number.\n"
  end

  def model_error(_reason) do
    "Model command could not be completed.\n"
  end

  @doc "Renders bounded catalog entries with explicit current and availability state."
  @spec sessions([Entry.t()], String.t(), :active | :all | :archived) :: iodata()
  def sessions(entries, current_identifier, filter) do
    visible = Enum.filter(entries, &visible?(&1, filter))

    case visible do
      [] -> "No matching sessions.\n"
      records -> ["Sessions:\n", session_lines(records, current_identifier)]
    end
  end

  @doc "Renders one completed session-management transition."
  @spec session_event(atom(), String.t()) :: iodata()
  def session_event(:archived, identifier) do
    ["Archived session ", safe(identifier), ".\n"]
  end

  def session_event(:renamed, label) do
    ["Session renamed to ", safe(label), ".\n"]
  end

  def session_event(:restored, identifier) do
    ["Restored session ", safe(identifier), ".\n"]
  end

  def session_event(:selected, identifier) do
    ["Selected session ", safe(identifier), ".\n"]
  end

  @doc "Renders a bounded session-management failure and safe next action."
  @spec session_error(term()) :: iodata()
  def session_error(%Normalized{} = error) do
    ["Session command failed (", safe(error.code), "): ", safe(error.message), hint(error.hint)]
  end

  def session_error(:ambiguous) do
    "Session name is ambiguous. Use its immutable ID.\n"
  end

  def session_error(:already_exists) do
    "That session ID already exists. Choose another ID or resume it.\n"
  end

  def session_error(:not_found) do
    "Session was not found. Run /sessions to inspect this workspace.\n"
  end

  def session_error(:unavailable) do
    "Session state is unavailable. Inspect its local state before continuing.\n"
  end

  def session_error(:session_not_persisted) do
    "Complete the first turn before renaming or archiving this session.\n"
  end

  def session_error(_reason) do
    "Session command could not be completed.\n"
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
    SafeLine.text(value, 2_048)
  end

  defp visible?(%Entry{}, :all) do
    true
  end

  defp visible?(%Entry{archive: :active}, :active) do
    true
  end

  defp visible?(%Entry{archive: {:archived, %DateTime{}}}, :archived) do
    true
  end

  defp visible?(%Entry{}, _filter) do
    false
  end

  defp session_lines(entries, current_identifier) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, position} -> session_line(entry, current_identifier, position) end)
  end

  defp session_line(entry, current_identifier, position) do
    [
      Integer.to_string(position),
      ". ",
      current(entry.id == current_identifier),
      safe(entry.label),
      "  ",
      safe(entry.id),
      "  ",
      session_details(entry),
      "\n"
    ]
  end

  defp current(true) do
    "* "
  end

  defp current(false) do
    "  "
  end

  defp model_lines(models, current_model) do
    models
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, position} -> model_line(entry, current_model, position) end)
  end

  defp model_line(entry, current_model, position) do
    [
      Integer.to_string(position),
      ". ",
      current(entry == current_model),
      safe(entry),
      "\n"
    ]
  end

  defp model(nil) do
    "selection required"
  end

  defp model(value) do
    safe(value)
  end

  defp session_details(%Entry{availability: :unavailable}) do
    "unavailable"
  end

  defp session_details(%Entry{archive: {:archived, _timestamp}}) do
    "archived"
  end

  defp session_details(%Entry{} = entry) do
    [safe(entry.provider), "/", safe(entry.model)]
  end

  defp hint(nil) do
    "\n"
  end

  defp hint(value) do
    ["\n  Hint: ", safe(value), "\n"]
  end

  defp web(true) do
    "enabled"
  end

  defp web(false) do
    "disabled"
  end
end
