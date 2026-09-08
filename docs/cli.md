# Command-line interface

The CLI runs anonymous or persistent agent tasks and provides an interactive prompt with session and model selection. Text terminals support per-operation approval prompts; automation uses versioned JSONL and stable exit categories. Interactive provider selection is not available.

## Available commands

| Invocation | Current behavior |
| --- | --- |
| `draught --help` or `draught help` | Prints command help. |
| `draught --version` or `draught version` | Prints the Draught version. |
| `draught doctor` | Runs read-only configuration, workspace, and provider checks. |
| `draught "TASK"` | Executes one anonymous task and streams its result. |
| `draught` or `draught interactive` | Opens an interactive text session on a terminal. |
| `draught --session ID "TASK"` | Creates a named session and streams its first task. |
| `draught --resume ID "TASK"` | Continues and streams an existing named session. |
| `draught --resume ID` | Opens an interactive terminal session for the selected identifier; headless use requires a task. |

Use `--` when task text begins with an option-like token:

```shell
draught -- "--explain this argument"
```

## Options

| Option | Meaning |
| --- | --- |
| `--provider NAME` | Selects a configured profile by name. |
| `--model MODEL` | Selects a model for this invocation. |
| `--base-url URL` | Overrides the selected profile endpoint when the profile is not credential-bound. |
| `--session ID` | Creates a persistent named session for the supplied task. |
| `--resume ID` | Continues a persistent named session with the supplied task. |
| `--web` / `--no-web` | Enables or disables guarded page fetching. |
| `--web-search` / `--no-web-search` | Enables or disables guarded search. |
| `--web-search-url URL` | Selects the explicit SearXNG-compatible JSON search endpoint. |
| `--output text\|jsonl` | Selects human-readable or machine-readable output where supported. |
| `--color auto\|always\|never` | Controls terminal label styling and activity rendering; model content remains unstyled. |
| `--diagnostics` / `--no-diagnostics` | Records the diagnostics preference; it does not expand doctor output in this slice. |
| `--help` | Requests command help. |
| `--version` | Requests version output. |

Help and version invocations cannot be combined with operational options. `doctor` does not accept session or resume options. Invalid combinations are usage errors.

## Anonymous task execution

`draught "TASK"` resolves configuration, loads the optional bounded `AGENTS.md` guidance, constructs the selected provider, and prepares the standard coding-tool registry for the current working directory. It then starts a temporary Draught session with journaling disabled, runs one turn through the bounded agent runner, waits for the terminal result, and stops the session.

The command is anonymous in the sense that it has no user-selected session identifier and retains no CLI conversation history. A subsequent command starts a separate task. If a tool effect completes before a later failure, timeout, cancellation, or process interruption, that effect remains committed. The one-shot command does not attempt rollback and does not retain a task journal.

Ollama model selection follows the provider inventory:

- An explicit `--model MODEL`, `DRAUGHT_MODEL`, or configured `model` is validated directly.
- With no selected model, exactly one compatible installed model is selected automatically.
- Zero or multiple compatible models produce an actionable provider error.

The one-shot path requests provider streaming. Text deltas are printed in order as they arrive. Reasoning deltas are not displayed. Tool events expose only the validated tool name, outcome, and normalized error code; call identifiers, arguments, output, provenance, and provider payloads are excluded.

The interactive prompt separates input from responses with a rounded, open-sided frame and a `›` marker. Its top rail keeps the active model and workspace visible before the `/help` and `/model` hints; paths inside the current user's home use `~`. The frame permits ordinary line wrapping, truncates the rail to the detected width, and falls back to `>` on narrow terminals. Assistant segments use spacing without speaker labels; indented `Tool:` records identify tool activity. These distinctions remain visible with `--color never`. Redirected text and JSONL retain their plain output formats.

On a text terminal at least 40 columns wide, the command displays a compact activity indicator after a short delay while it is waiting for the first visible event. Each turn shuffles the full set of 510 short fantasy-themed captions, changing captions roughly every four seconds without repeating within a cycle. Captions do not describe execution stages or report completed work. The indicator is cleared before output and has an independent 16 KiB lifetime output limit. It is disabled for `--color never`, redirected output, unavailable or narrow terminal dimensions, and JSONL. A closed output pipe cancels the active session and returns the internal-error status instead of continuing to execute unseen work.

JSONL emits one record per visible event followed by exactly one terminal record. Every record is written to standard output, has a monotonically increasing `sequence`, and ends with one newline:

```jsonl
{"content":"Final assistant text","event":"text_delta","iteration":1,"schema":"draught.cli/v1","sequence":1,"type":"event"}
{"content":null,"content_streamed":true,"finish_reason":"stop","schema":"draught.cli/v1","sequence":2,"status":"ok","type":"terminal","usage":null}
```

When the final provider iteration emitted no visible text delta, the terminal record carries the final assistant `content` and sets `content_streamed` to `false`. If the terminal response extends already streamed text, `content` contains only the missing suffix. A terminal response that disagrees with visible streamed text fails closed. When usage is available and representable, `usage` contains canonical token counts. A normalized task failure is written to standard error in text mode or as the terminal standard-output record in JSONL mode. Setup failures use the same terminal envelope without reflecting rejected configuration values.

## Terminal approvals

With the default `ask` risk mode, effectful operations display a separate approval block when standard input, output, and error are attached to terminals and output is text. This applies to anonymous tasks, named tasks, and the interactive prompt. Read operations do not prompt.

The block identifies the tool, target, bounded reason, and risk before showing the complete operation as indented JSON, including the workspace and exact command arguments or replacement text. Interactive colour modes highlight JSON token types; `--color never` keeps the same structure without terminal controls. Exact file replacements also show a bounded proposed diff derived from the validated expected and replacement fragments. The diff does not read the workspace, infer line numbers, or replace the complete JSON details.

Type `y` or `yes` to approve that operation once. Enter, `n`, and other input deny it. Missing, malformed, deeply nested, or oversized presentations are denied without requesting input; values are never truncated. There is no session-wide grant, and a resumed session never reuses an earlier decision.

Approval has no wall-clock deadline. The activity indicator and tool execution budget pause while input is pending, so the user may inspect the operation before deciding. Provider calls, actual tool execution, command processes, output, and iteration counts remain bounded. End of input, input failure, requester termination, and cancellation fail closed. Already completed effects are not rolled back.

Erlang cannot cancel an outstanding terminal line read. Draught therefore invalidates that input device when a pending read is abandoned, discards any late reply, and refuses further reads from that device in the same VM. A fresh CLI process is required after this failure. Applications that restart the input coordinator must likewise restart the VM before using local interactive input again.

Redirected streams, JSONL, and application-facing task APIs do not acquire approval input. Their default effectful-tool result remains `approval_required`. `deny` blocks effectful tools before approval; `allow` deliberately bypasses these prompts. Preview text can contain sensitive file contents or arguments: it is displayed only in the approval block and is excluded from the event stream, telemetry, and journals.

## Application-supplied approval policies

Applications embedding the CLI task APIs can pass an approval adapter through `Draught.CLI.Task.Dependencies.new/2` or the `task` overrides of `Draught.CLI.Dependencies.new/1`:

```elixir
{:ok, dependencies} =
  Draught.CLI.Dependencies.new(
    task: [approval: {MyApp.ApprovalPolicy, policy_configuration}]
  )
```

The adapter implements `Draught.Tool.Approval.Policy` and receives canonical, bounded metadata with an optional sensitive operation preview. An explicit dependency replaces the risk-derived default and any low-level preparation approval option and takes precedence over terminal prompts. Omitting it or passing `nil` preserves application task defaults; CLI text terminals install the interactive policy described above. The configured risk allowlist is checked first: an adapter cannot admit writes under `deny`, enable web access, change the workspace, or increase execution budgets. An injected policy can still deny a call under `allow`.

Anonymous, named-create, and resumed tasks use the same preparation boundary. A resumed invocation supplies its own policy; adapter configuration and earlier grants are not restored from the journal or session binding. Approval waiting remains inside the tool timeout. This injection boundary does not add terminal prompts or a configuration-file setting.

## Named task execution

Create a named session by supplying a task and a portable session identifier:

```shell
draught --session review "inspect the authentication changes"
```

Continue it with another task:

```shell
draught --resume review "address the remaining test failure"
```

Named sessions are stored under the user's state directory, outside the workspace. Each journal preserves the retained canonical conversation required by the provider, including the effective system instruction loaded for the first turn. Streaming deltas are transient and are not journaled; the validated provider result remains authoritative for replay. Resume reuses the recorded system instruction without re-reading `AGENTS.md`. A session is bound to its profile, provider connection, provider adapter, exact negotiated capability set, exact model, web permissions, web adapters, and configured search endpoint when it is created. Resume fails before provider execution if the current selection conflicts with that binding. Omitting `--model` during resume reuses the recorded model. Bindings created before capability identity was introduced are upgraded atomically after their first verified resume.

A session resumes from its last complete conversation boundary. Successful turns retain their assistant response. Failed or interrupted turns retain their terminal outcome for audit but discard that turn's partial messages from model replay; completed tool effects remain committed and should be inspected before retrying. Empty, malformed, oversized, unsafe, or concurrently leased session state fails closed. A second create with the same identifier is rejected. Bare `draught --resume ID` enters the prompt loop on a terminal and requires a task argument when standard output is redirected or JSONL is selected.

## Interactive sessions

Interactive mode resolves configuration and inspects the bounded Ollama inventory before displaying its session card. Exactly one compatible model is selected automatically. When several compatible models exist, the shell opens with `selection required` as its model and rejects task prompts until `/model` selects one. The shell owns a stable generated or supplied session identifier and routes ordinary text through the named-session task path. Successful later turns resume the same durable journal. Slash-prefixed input is parsed as a CLI command and is never sent to the provider as task text.

The current commands are:

| Command | Behavior |
| --- | --- |
| `/help` or `/` | Displays the command index. |
| `/status` | Displays the current immutable ID, display name, provider, model, workspace, web state, and activity. |
| `/doctor` | Runs the read-only diagnostic command and returns to the prompt. |
| `/model [reference]` | Lists compatible models or selects one by list number or exact name. |
| `/sessions` | Lists bounded active, archived, and unavailable records for the current workspace. |
| `/resume [reference]` | Selects an active session by list number, exact ID, or unique display name. With no argument, lists active sessions. |
| `/new [ID]` | Starts a fresh unpersisted session using the current base configuration. A generated UUID is used when the ID is omitted. |
| `/rename NAME` | Changes the display name of the current persisted session without changing its ID. |
| `/archive [ID or name]` | Soft-archives the selected active session, defaulting to the current persisted session. Archiving the current session switches the shell to a fresh unpersisted session. |
| `/restore [ID or name]` | Restores an archived session. With no argument, lists archived sessions. |
| `/exit` | Closes the prompt and prints its current session ID. |

Model discovery preserves Ollama's inventory order and exposes only models that meet the complete agent capability requirement. Exact names take precedence over one-based positions, including when a model name is numeric. A model may change only while the current session is idle and has no durable history. Once its first turn succeeds, the journal binding fixes the provider and model; use `/new` before selecting another model. The shell retains its unchanged base configuration, so a session-local model choice cannot leak into a fresh or resumed session.

Session names are display metadata and need not be unique. An ambiguous name must be replaced with its immutable ID. Catalog views assign one-based positions, so `/resume 2` selects the second active record from the deterministic filtered list. Exact IDs and unique names take precedence over positions. Session catalog discovery is read-only and bounded; it does not replay journals. Exact IDs use direct lookup, so known sessions can still be archived or restored when a complete listing exceeds its entry limit. Corrupt or unsafe records are shown only by their validated ID as unavailable and cannot be selected. Archived sessions are rejected at the storage boundary for both interactive and headless resume until restored.

The parser reserves direct-command input beginning with `!`, file lookup input beginning with `@`, and the remaining documented slash command names. Those effects return an explicit unavailable result until their policy boundaries are connected.

The prompt loop is text- and terminal-only. A bounded provider, runner, or tool failure ends only the active turn; the shell reports the failure and accepts another prompt from the last complete durable history. It restores its terminal boundary after exit, end of input, or an input failure and prints `Session ID: ID` on ordinary exit. Active-turn keyboard cancellation, fuzzy command and model completion, provider selection, and queued input remain pending.

## Doctor

`draught doctor` is read-only. It resolves the same configuration sources used by the CLI, checks that the current workspace is an accessible read-write directory, and evaluates the selected provider.

For Ollama without an explicit model, doctor contacts the tags and model-detail discovery endpoints and reports compatible and incompatible installed models. With an explicit model, it requests only that model's details and validates its capabilities. For an OpenAI-compatible profile, doctor does not contact the remote endpoint or verify remote model capabilities; it returns a not-checked provider result rather than reporting the provider as healthy.

The text form is intended for a terminal:

```shell
draught doctor
```

The JSONL form emits one complete JSON object followed by a newline:

```shell
draught doctor --output jsonl
```

The current JSONL schema identifier is `draught.cli/v1`. Streaming tasks use `event` and `terminal` records. Doctor, help, and version use their corresponding record types. Argument-parsing errors remain text because invalid input may prevent the output format from being resolved safely.

### Task JSONL records

| Record | Public fields |
| --- | --- |
| Text delta | `schema`, `sequence`, `type`, `event`, `iteration`, `content` |
| Tool call | `schema`, `sequence`, `type`, `event`, `iteration`, `name` |
| Tool result | `schema`, `sequence`, `type`, `event`, `iteration`, `name`, `status`, `code` |
| Success terminal | `schema`, `sequence`, `type`, `status`, `content`, `content_streamed`, `finish_reason`, `usage` |
| Error terminal | `schema`, `sequence`, `type`, `status`, `category`, `kind`, `code`, `message`, `retryable` |

The projector has a 1 MiB cumulative limit for nonterminal rendered output. Terminal content, error codes, and error messages have independent field limits, and the complete terminal record cannot exceed 64 KiB. This separate terminal budget allows a bounded error to describe a nonterminal limit failure. Unknown runner events, inconsistent streamed and final text, a second terminal outcome, encoding failures, and output-limit violations fail closed.

## Output and exit behavior

Normal help, version, task, and doctor output is written to standard output. Text task failures, usage errors, configuration errors, unavailable-mode errors, and provider-construction errors are written to standard error. JSONL task outcomes, including terminal failures, use standard output as one ordered record stream. A failed doctor report is rendered to standard output and exits in the provider category.

Exit categories are stable at the CLI boundary:

| Category | Code | Current use |
| --- | ---: | --- |
| Success | 0 | Help, version, a completed anonymous or named task, and a healthy doctor result. |
| Usage | 2 | Invalid syntax, option combinations, or configuration. |
| Provider | 3 | Provider construction failures or provider and workspace checks reported by doctor. |
| Execution | 4 | Task or web-tool execution failures. |
| Session | 5 | Named-session lifecycle, binding, persistence, or resume failures. |
| Internal | 70 | Unexpected internal failure. |
| Interrupted | 130 | A normalized task cancellation. |

Automation should select `--output jsonl`, parse the `schema`, `type`, and `status` or `category` fields, and use the process exit code as the primary result category.
