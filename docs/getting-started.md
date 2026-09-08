# Getting started

This guide covers installing the executable, configuring a local Ollama profile, selecting a model, running diagnostics, and executing anonymous, named, or interactive tasks.

## 1. Install Draught

Install the checksummed native archive for the current system by following [Installation](../README.md#installation). The archive includes its Erlang runtime and does not require a system Elixir or Erlang/OTP installation.

```shell
draught --version
```

Source and escript builds remain available to contributors. See [Distribution](distribution.md) for native target selection, source builds, upgrades, and uninstalling.

## 2. Prepare Ollama

Install Ollama using its [official installation instructions](https://ollama.com/download). If the installation does not start the service automatically, run it in a separate terminal:

```shell
ollama serve
```

Then install a model:

```shell
ollama pull qwen3
ollama list
```

Draught's built-in `ollama` profile connects to `http://localhost:11434`. The selected model must report chat, streaming, and tool-call capabilities through Ollama's discovery API.

DeepSeek-R1 is also available in several local sizes through Ollama. For example:

```shell
ollama pull deepseek-r1:8b
draught doctor --model deepseek-r1:8b
```

Model catalog labels can change. Draught uses the capability metadata reported by the installed model rather than a hard-coded model allowlist; `draught doctor` is the authoritative compatibility check for the local installation.

## 3. Check the environment

Run the read-only doctor command from the workspace in which Draught will operate:

```shell
draught doctor
```

Doctor checks the resolved configuration, workspace access, Ollama reachability, and the Ollama model inventory. OpenAI-compatible connectivity diagnostics are not implemented in this slice, so those profiles return a not-checked provider result. Doctor does not run inference or modify models.

For automation, request one JSON object per output line:

```shell
draught doctor --output jsonl
```

## 4. Select a model

Ollama discovery examines every installed model and classifies it against Draught's required capabilities. Selection happens after that filtering:

- No installed models produces a provider error.
- Installed models with no compatible entry produce a provider error.
- Exactly one compatible model is selected automatically when no model is configured.
- More than one compatible model requires an explicit selection and produces a provider error otherwise.
- An explicitly selected missing or incompatible model produces a provider error.

Select a model for one command with `--model`:

```shell
draught doctor --model qwen3
```

To persist the choice, create the user configuration file described in [Configuration](configuration.md):

```json
{
  "profile": "ollama",
  "model": "qwen3"
}
```

You can also set `DRAUGHT_MODEL=qwen3` for the current environment.

## 5. Run one task

Run a task from the workspace that Draught may inspect:

```shell
draught "inspect this workspace"
```

If more than one compatible Ollama model is installed, select one explicitly:

```shell
draught --model qwen3 "inspect this workspace"
```

The command creates a temporary supervised session, executes one turn, streams visible assistant text, waits for its terminal result, and stops the session. It does not create a session journal. On an interactive terminal, a compact bounded activity indicator is displayed while the provider has not produced visible output. `--color never`, redirected or narrow output, and `--output jsonl` disable the indicator. JSONL emits ordered event records followed by exactly one terminal record.

The default `ask` risk mode permits read operations. On a text terminal, review the operation preview and type `y` to approve an edit or command once; Enter denies it. Redirected or JSONL tasks return approval-required results instead of reading input. See [Terminal approvals](cli.md#terminal-approvals) for deadlines and failure behavior.

## 6. Continue work in a named session

Create a named session for work that spans multiple invocations:

```shell
draught --session review "inspect this workspace"
```

Continue from its successful assistant response:

```shell
draught --resume review "continue this work"
```

The session retains the complete provider conversation in the user state directory and remains bound to its original provider connection, exact model, and negotiated capabilities. Resume rejects incompatible changes before provider execution. Use a different identifier to start unrelated work.

## 7. Use the interactive prompt

Run Draught without a task argument from an interactive terminal:

```shell
draught
```

Startup resolves the same configuration as a one-shot task, inspects the compatible model inventory, generates one session identifier, and displays the provider, model, workspace, session, and web state before accepting input. One compatible Ollama model is selected automatically. If several are available, select one inside the shell before entering a task:

```text
/model
/model 2
```

`/model` lists compatible models in provider order. Its optional reference is an exact name or one-based list position. The selected model is saved in the user configuration and becomes the default for later launches and fresh sessions opened with `/new`. The selection is fixed after a session establishes durable state; start `/new` before changing models. Ordinary text starts the first durable named turn and subsequent turns resume that session. Entering `/` displays the command index. End of input and `/exit` restore the terminal and print `Session ID: ID`.

Manage persistent sessions without leaving the shell:

```text
/sessions
/rename Workspace review
/new
/resume Workspace review
/archive
/restore Workspace review
```

`/resume` and `/restore` accept either an immutable ID or a unique display name. Omitting their argument lists the relevant active or archived records. Archive is a reversible metadata transition; an archived record cannot resume until restored. The [CLI guide](cli.md#interactive-sessions) defines the complete command behavior.

Start the shell with an explicit identifier or resume target when needed:

```shell
draught --session review
draught --resume review
```

Prompt-free interactive use requires a terminal and text output. A headless `--session` or `--resume` invocation still requires a task argument. Use one-shot mode and `--output jsonl` for automation.

## 8. Optional web access

Web access is disabled by default. Enable guarded page fetching for one invocation with:

```shell
draught "read the Elixir documentation at https://elixir-lang.org" --web
```

Enable guarded search independently by supplying a SearXNG-compatible JSON endpoint:

```shell
draught "find the current Elixir documentation" --web-search --web-search-url https://search.example/search
```

The model receives only the enabled web tools. Each request retains the network risk and approval checks, and the transport applies the redirect, address, content, size, and timeout controls documented in [Web access](web-access.md). Each anonymous task starts without prior conversation state.

## 9. Optional hosted compatible provider

The OpenAI-compatible provider can connect to a trusted hosted endpoint. This example follows the current [DeepSeek API configuration](https://api-docs.deepseek.com/):

```json
{
  "profile": "deepseek",
  "model": "deepseek-v4-pro",
  "profiles": {
    "deepseek": {
      "provider": "openai-compatible",
      "base_url": "https://api.deepseek.com",
      "credential_env": "DEEPSEEK_API_KEY"
    }
  }
}
```

Store this object in the user configuration file, set `DEEPSEEK_API_KEY` in the environment, and run `draught`. Hosted requests transmit conversation and tool context to the configured service and may incur provider charges. The local Ollama path keeps inference on the configured local service and requires no API credential.

See [CLI](cli.md) for command and exit behavior and [Ollama provider](providers/ollama.md) for discovery details.
