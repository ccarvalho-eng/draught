# Command-line interface

The current CLI is an intermediate kernel. It provides bounded argument parsing, configuration resolution, help, version reporting, diagnostics, text rendering, JSONL rendering, and stable exit categories. It does not yet execute agent tasks or interactive sessions.

## Available commands

| Invocation | Current behavior |
| --- | --- |
| `draught --help` or `draught help` | Prints command help. |
| `draught --version` or `draught version` | Prints the Draught version. |
| `draught doctor` | Runs read-only configuration, workspace, and provider checks. |
| `draught "TASK"` | Parses the task and returns an unavailable execution result. |
| `draught` or `draught interactive` | Parses interactive mode and returns an unavailable execution result. |
| `draught --session ID` or `draught --resume ID` | Parses session intent; session execution is unavailable. |

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
| `--session ID` | Selects a session identifier for a future execution path. |
| `--resume ID` | Selects a session to resume in a future execution path. |
| `--web` / `--no-web` | Resolves the web setting; no task execution consumes it in this slice. |
| `--output text\|jsonl` | Selects human-readable or machine-readable output where supported. |
| `--color auto\|always\|never` | Records the requested color mode; current output is unstyled. |
| `--diagnostics` / `--no-diagnostics` | Records the diagnostics preference; it does not expand doctor output in this slice. |
| `--help` | Requests command help. |
| `--version` | Requests version output. |

Help and version invocations cannot be combined with operational options. `doctor` does not accept session or resume options. Invalid combinations are usage errors.

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

The current JSONL schema identifier is `draught.cli/v1`. Doctor results use type `doctor`; configuration and unavailable-execution results use type `error`; help and version use their corresponding types. Argument-parsing errors remain text because invalid input may prevent the output format from being resolved safely.

## Output and exit behavior

Normal help, version, and successful doctor output is written to standard output. Usage and configuration errors are written to standard error. A failed doctor result is rendered to standard output and exits in the provider category. Unavailable task or interactive execution is written to standard error.

Exit categories are stable at the CLI boundary:

| Category | Code | Current use |
| --- | ---: | --- |
| Success | 0 | Help, version, and a healthy doctor result. |
| Usage | 2 | Invalid syntax, option combinations, or configuration. |
| Provider | 3 | Provider or workspace checks reported by doctor. |
| Execution | 4 | Task or interactive execution is unavailable; the category also covers later execution failures. |
| Session | 5 | Reserved for session lifecycle failures. |
| Internal | 70 | Unexpected internal failure. |
| Interrupted | 130 | Reserved for interrupted execution. |

Automation should select `--output jsonl`, parse the `schema`, `type`, and `status` or `category` fields, and use the process exit code as the primary result category.
