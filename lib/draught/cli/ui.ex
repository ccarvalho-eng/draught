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

  @skill_description_bytes 44

  @doc "Renders the initial bounded session card for a known terminal width."
  @spec banner(State.t(), pos_integer(), boolean()) :: iodata()
  def banner(%State{} = state, width, styled?)
      when is_integer(width) and width > 0 and is_boolean(styled?) do
    Owl.banner(state, width, styled?)
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
      "\n  Web fetch: ",
      web(state.web),
      "\n  Web search: ",
      web(state.web_search),
      "\n  Activity: ",
      Atom.to_string(state.phase),
      "\n"
    ]
  end

  @doc "Renders enabled built-in tools and the explicit optional web-tool state."
  @spec tools(map()) :: iodata()
  def tools(%{entries: entries, web_fetch: web_fetch, web_search: web_search}) do
    [
      "Tools:\n",
      tool_lines(entries),
      "Web tools:\n",
      "  web_fetch: ",
      enabled(web_fetch),
      "\n  web_search: ",
      enabled(web_search),
      "\n"
    ]
  end

  @doc "Renders the effective non-secret workspace and tool authority."
  @spec permissions(map()) :: iodata()
  def permissions(%{
        admitted_risks: admitted_risks,
        approval: approval,
        risk: risk,
        web_fetch: web_fetch,
        web_search: web_search,
        workspace: workspace
      }) do
    [
      "Permissions:\n",
      "  Workspace: ",
      safe(workspace),
      "\n  Risk mode: ",
      Atom.to_string(risk),
      "\n  Admitted risks: ",
      risk_list(admitted_risks),
      "\n  Approval: ",
      approval(approval),
      "\n  Web fetch: ",
      enabled(web_fetch),
      "\n  Web search: ",
      enabled(web_search),
      "\n"
    ]
  end

  @doc "Renders a stable failure when a read-only inspection cannot be produced."
  @spec inspection_error() :: iodata()
  def inspection_error do
    "The active tool configuration could not be inspected.\n"
  end

  @doc "Renders a bounded input boundary with persistent session context in its rail."
  @spec input_area(:open | :close, State.t(), pos_integer(), boolean()) :: iodata()
  def input_area(phase, %State{} = state, width, styled? \\ false)
      when phase in [:open, :close] and is_integer(width) and width > 0 and is_boolean(styled?) do
    Owl.input_area(phase, state, width, styled?)
  end

  @doc "Renders the fixed tool-activity label with an explicit terminal styling decision."
  @spec tool_label(boolean()) :: iodata()
  def tool_label(styled?) when is_boolean(styled?) do
    Owl.tool_label(styled?)
  end

  @doc "Returns the terminal control sequence that clears the screen and homes the cursor."
  @spec clear() :: String.t()
  def clear do
    "\e[2J\e[H"
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
    ["Selected model ", safe(selected_model), " and saved it as the user default.\n"]
  end

  @doc "Renders a bounded model command failure and safe next action."
  @spec model_error(term()) :: iodata()
  def model_error(%Normalized{} = error) do
    ["Model command failed (", safe(error.code), "): ", safe(error.message), hint(error.hint)]
  end

  def model_error(:preference_not_saved) do
    "Model selection was not changed because the user configuration could not be updated.\n"
  end

  def model_error(:preference_outcome_unknown) do
    "The user configuration update could not be confirmed. Restart Draught before relying on the selected default.\n"
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

  @doc "Renders discovered skill metadata without loading instruction bodies."
  @spec skills(%{required(:entries) => [map()], required(:rejected) => non_neg_integer()}) ::
          iodata()
  def skills(%{entries: [], rejected: rejected}) do
    [
      "No skills found. Add .draught/skills/NAME/SKILL.md or .agents/skills/NAME/SKILL.md.\n",
      rejected_skills(rejected)
    ]
  end

  def skills(%{entries: entries, rejected: rejected}) do
    [skill_lines(entries), rejected_skills(rejected)]
  end

  @doc "Renders the compact index for the separate custom and built-in skill catalogs."
  @spec skill_index() :: iodata()
  def skill_index do
    [
      "Skill catalogs:\n",
      "  /custom-skills   Workspace and user skills\n",
      "  /builtin-skills  Packaged skills\n",
      "  /skill REF       Apply from the last listed catalog\n"
    ]
  end

  @doc "Renders the selected skill before its ordinary agent turn starts."
  @spec skill_selected(String.t()) :: iodata()
  def skill_selected(name) when is_binary(name) do
    ["Using skill ", safe(name), ".\n"]
  end

  @doc "Renders a bounded skill discovery or selection failure."
  @spec skill_error(atom()) :: iodata()
  def skill_error(:invalid_name) do
    "Skill names must use lower-case letters, digits, and single hyphens.\n"
  end

  def skill_error(:not_found) do
    "Skill was not found. Run /skills to inspect available skills.\n"
  end

  def skill_error(:too_large) do
    "Skill instructions are too large for one agent turn.\n"
  end

  def skill_error(_reason) do
    "Skills are unavailable. Check the configured skill directories.\n"
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
    "Complete the first turn before archiving this session.\n"
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
    width = reference_width(entries)

    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, position} ->
      session_line(entry, current_identifier, position, width)
    end)
  end

  defp skill_lines(entries) do
    width = reference_width(entries)

    entries
    |> Enum.with_index(1)
    |> Enum.chunk_by(fn {entry, _position} -> entry.origin end)
    |> Enum.map(&skill_group(&1, width))
  end

  defp skill_group([{entry, _position} | _rest] = entries, width) do
    [skill_origin(entry.origin), ":\n", Enum.map(entries, &skill_line(&1, width))]
  end

  defp tool_lines(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, position} -> tool_line(entry, position) end)
  end

  defp tool_line(%{description: description, name: name, risk: risk}, position) do
    [
      Integer.to_string(position),
      ". ",
      safe(name),
      "  ",
      Atom.to_string(risk),
      "  ",
      safe(description),
      "\n"
    ]
  end

  defp skill_line({%{description: description, name: name}, position}, width) do
    position =
      position
      |> Integer.to_string()
      |> String.pad_leading(width)

    [
      position,
      ". ",
      safe(name),
      "  ",
      skill_description(description),
      "\n"
    ]
  end

  defp skill_origin(:workspace_draught) do
    "Workspace skills"
  end

  defp skill_origin(:workspace_agents) do
    "Workspace shared skills"
  end

  defp skill_origin(:user_draught) do
    "User skills"
  end

  defp skill_origin(:user_agents) do
    "User shared skills"
  end

  defp skill_origin(:builtin) do
    "Built-in skills"
  end

  defp skill_description(description) do
    description
    |> SafeLine.text(2_048)
    |> bounded_skill_description()
  end

  defp bounded_skill_description(description)
       when byte_size(description) <= @skill_description_bytes do
    description
  end

  defp bounded_skill_description(description) do
    prefix = SafeLine.text(description, @skill_description_bytes - 3)
    prefix <> "..."
  end

  defp rejected_skills(0) do
    []
  end

  defp rejected_skills(count) do
    ["Skipped ", Integer.to_string(count), " invalid skill entries.\n"]
  end

  defp session_line(entry, current_identifier, position, width) do
    position =
      position
      |> Integer.to_string()
      |> String.pad_leading(width)

    [
      position,
      ". ",
      current(entry.id == current_identifier),
      session_identity(entry),
      "  ",
      session_details(entry),
      "\n"
    ]
  end

  defp reference_width(entries) do
    entries
    |> length()
    |> Integer.to_string()
    |> String.length()
  end

  defp session_identity(%Entry{id: id, label: label}) when label != id do
    safe(label)
  end

  defp session_identity(%Entry{preview: preview}) when is_binary(preview) do
    safe(preview)
  end

  defp session_identity(%Entry{id: id}) do
    safe(id)
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

  defp approval(:application_policy) do
    "application policy"
  end

  defp approval(:automatic) do
    "automatic for admitted tools"
  end

  defp approval(:effectful) do
    "required for effectful tools"
  end

  defp enabled(true) do
    "enabled"
  end

  defp enabled(false) do
    "disabled"
  end

  defp risk_list(risks) do
    Enum.map_join(risks, ", ", &Atom.to_string/1)
  end

  defp web(true) do
    "enabled"
  end

  defp web(false) do
    "disabled"
  end
end
