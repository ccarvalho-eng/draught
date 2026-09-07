# Command-line interface

The current CLI provides bounded argument parsing, configuration resolution, help, version reporting, diagnostics, streaming anonymous tasks, and persistent named tasks. It renders incremental terminal text or versioned JSONL and uses stable exit categories. Interactive input and enabled web execution are not available.

## Available commands

| Invocation | Current behavior |
| --- | --- |
| `draught --help` or `draught help` | Prints command help. |
| `draught --version` or `draught version` | Prints the Draught version. |
| `draught doctor` | Runs read-only configuration, workspace, and provider checks. |
| `draught "TASK"` | Executes one anonymous task and streams its result. |
| `draught` or `draught interactive` | Parses interactive mode and returns an unavailable execution result. |
| `draught --session ID "TASK"` | Creates a named session and streams its first task. |
| `draught --resume ID "TASK"` | Continues and streams an existing named session. |
| `draught --resume ID` | Parses resume intent; interactive resumed execution is unavailable. |

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
| `--web` / `--no-web` | Resolves the web setting. An enabled value makes task execution fail explicitly until a search adapter is connected. |
| `--output text\|jsonl` | Selects human-readable or machine-readable output where supported. |
| `--color auto\|always\|never` | Controls whether terminal-only activity rendering is allowed; task text remains unstyled. |
| `--diagnostics` / `--no-diagnostics` | Records the diagnostics preference; it does not expand doctor output in this slice. |
| `--help` | Requests command help. |
| `--version` | Requests version output. |

Help and version invocations cannot be combined with operational options. `doctor` does not accept session or resume options. Invalid combinations are usage errors.

## Anonymous task execution

`draught "TASK"` resolves configuration, constructs the selected provider, and prepares the standard coding-tool registry for the current working directory. It then starts a temporary Draught session with journaling disabled, runs one turn through the bounded agent runner, waits for the terminal result, and stops the session.

The command is anonymous in the sense that it has no user-selected session identifier and retains no CLI conversation history. A subsequent command starts a separate task. If a tool effect completes before a later failure, timeout, cancellation, or process interruption, that effect remains committed. The one-shot command does not attempt rollback and does not retain a task journal.

Ollama model selection follows the provider inventory:

- An explicit `--model MODEL`, `DRAUGHT_MODEL`, or configured `model` is validated directly.
- With no selected model, exactly one compatible installed model is selected automatically.
- Zero or multiple compatible models produce an actionable provider error.

The one-shot path requests provider streaming. Text deltas are printed in order as they arrive. Reasoning deltas are not displayed. Tool events expose only the validated tool name, outcome, and normalized error code; call identifiers, arguments, output, provenance, and provider payloads are excluded.

On a text terminal at least 40 columns wide, the command displays a compact activity indicator after a short delay while it is waiting for the first visible event. The indicator is cleared before output and has an independent 16 KiB lifetime output limit. It is disabled for `--color never`, redirected output, unavailable or narrow terminal dimensions, and JSONL. A closed output pipe cancels the active session and returns the internal-error status instead of continuing to execute unseen work.

JSONL emits one record per visible event followed by exactly one terminal record. Every record is written to standard output, has a monotonically increasing `sequence`, and ends with one newline:

```jsonl
{"content":"Final assistant text","event":"text_delta","iteration":1,"schema":"draught.cli/v1","sequence":1,"type":"event"}
{"content":null,"content_streamed":true,"finish_reason":"stop","schema":"draught.cli/v1","sequence":2,"status":"ok","type":"terminal","usage":null}
```

When the final provider iteration emitted no visible text delta, the terminal record carries the final assistant `content` and sets `content_streamed` to `false`. If the terminal response extends already streamed text, `content` contains only the missing suffix. A terminal response that disagrees with visible streamed text fails closed. When usage is available and representable, `usage` contains canonical token counts. A normalized task failure is written to standard error in text mode or as the terminal standard-output record in JSONL mode. Setup failures use the same terminal envelope without reflecting rejected configuration values.

## Named task execution

Create a named session by supplying a task and a portable session identifier:

```shell
draught --session review "inspect the authentication changes"
```

Continue it with another task:

```shell
draught --resume review "address the remaining test failure"
```

Named sessions are stored under the user's state directory, outside the workspace. Each journal preserves the retained canonical conversation required by the provider. Streaming deltas are transient and are not journaled; the validated provider result remains authoritative for replay. A session is bound to its profile, provider connection, provider adapter, exact negotiated capability set, and exact model when it is created. Resume fails before provider execution if the current selection conflicts with that binding. Omitting `--model` during resume reuses the recorded model. Bindings created before capability identity was introduced are upgraded atomically after their first verified resume.

Only a session whose durable history ends at a successful assistant response can resume automatically. Interrupted, failed, malformed, oversized, unsafe, or concurrently leased session state fails closed. A second create with the same identifier is rejected. Bare `draught --resume ID` remains unavailable until interactive input is implemented.

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
| Execution | 4 | Task execution failures, enabled web execution, or an unavailable interactive path. |
| Session | 5 | Named-session lifecycle, binding, persistence, or resume failures. |
| Internal | 70 | Unexpected internal failure. |
| Interrupted | 130 | A normalized task cancellation. |

Automation should select `--output jsonl`, parse the `schema`, `type`, and `status` or `category` fields, and use the process exit code as the primary result category.
