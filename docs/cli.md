# Command-line interface

The current CLI provides bounded argument parsing, configuration resolution, help, version reporting, diagnostics, and anonymous one-shot tasks. It renders terminal text or versioned JSONL and uses stable exit categories. Interactive input, named and resumed sessions, incremental streaming, and enabled web execution are not available in this slice.

## Available commands

| Invocation | Current behavior |
| --- | --- |
| `draught --help` or `draught help` | Prints command help. |
| `draught --version` or `draught version` | Prints the Draught version. |
| `draught doctor` | Runs read-only configuration, workspace, and provider checks. |
| `draught "TASK"` | Executes one anonymous task and prints its terminal result. |
| `draught` or `draught interactive` | Parses interactive mode and returns an unavailable execution result. |
| A task with `--session ID` or `--resume ID` | Returns an unavailable named-session result. |
| `draught --resume ID` | Parses resume intent; resumed execution is unavailable. |

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
| `--session ID` | Requests a named session, which is unavailable in this slice. |
| `--resume ID` | Requests a resumed session, which is unavailable in this slice. |
| `--web` / `--no-web` | Resolves the web setting. An enabled value makes task execution fail explicitly until a search adapter is connected. |
| `--output text\|jsonl` | Selects human-readable or machine-readable output where supported. |
| `--color auto\|always\|never` | Records the requested color mode; current output is unstyled. |
| `--diagnostics` / `--no-diagnostics` | Records the diagnostics preference; it does not expand doctor output in this slice. |
| `--help` | Requests command help. |
| `--version` | Requests version output. |

Help and version invocations cannot be combined with operational options. `doctor` does not accept session or resume options. Invalid combinations are usage errors.

## Anonymous task execution

`draught "TASK"` resolves configuration, constructs the selected provider, and prepares the standard coding-tool registry for the current working directory. It then starts a temporary Draught session with journaling disabled, runs one turn through the bounded agent runner, waits for the terminal result, and stops the session.

The command is anonymous in the sense that it has no user-selected session identifier and retains no CLI conversation history. A subsequent command starts a separate task. Named sessions and resume are not aliases for this mode and are rejected explicitly. If a tool effect completes before a later failure, timeout, cancellation, or process interruption, that effect remains committed. The one-shot command does not attempt rollback and does not retain a task journal.

Ollama model selection follows the provider inventory:

- An explicit `--model MODEL`, `DRAUGHT_MODEL`, or configured `model` is validated directly.
- With no selected model, exactly one compatible installed model is selected automatically.
- Zero or multiple compatible models produce an actionable provider error.

The one-shot path uses provider completion rather than provider streaming. Text mode prints only final visible assistant text and removes reasoning content and terminal control sequences. JSONL mode emits one terminal record:

```json
{
  "schema": "draught.cli/v1",
  "type": "task",
  "status": "ok",
  "content": "Final assistant text",
  "finish_reason": "stop",
  "usage": null
}
```

When usage is available, `usage` contains the canonical provider token counts. A normalized task failure is written to standard error as text or as one JSONL error record with `category`, `kind`, `code`, `message`, `hint`, and `retryable` fields. A setup-validation failure uses `category`, `code`, and `message` because execution did not begin.

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

The current JSONL schema identifier is `draught.cli/v1`. Successful task and doctor results use types `task` and `doctor`; failures use type `error`; help and version use their corresponding types. Argument-parsing errors remain text because invalid input may prevent the output format from being resolved safely.

## Output and exit behavior

Normal help, version, successful task, and successful doctor output is written to standard output. Usage, configuration, task, unavailable-mode, and provider-construction errors are written to standard error. A failed doctor report is rendered to standard output and exits in the provider category.

Exit categories are stable at the CLI boundary:

| Category | Code | Current use |
| --- | ---: | --- |
| Success | 0 | Help, version, a completed anonymous task, and a healthy doctor result. |
| Usage | 2 | Invalid syntax, option combinations, or configuration. |
| Provider | 3 | Provider construction failures or provider and workspace checks reported by doctor. |
| Execution | 4 | Task execution failures, enabled web execution, or an unavailable interactive path. |
| Session | 5 | Named-session and task-resume requests, or session lifecycle failures. |
| Internal | 70 | Unexpected internal failure. |
| Interrupted | 130 | A normalized task cancellation. |

Automation should select `--output jsonl`, parse the `schema`, `type`, and `status` or `category` fields, and use the process exit code as the primary result category.
