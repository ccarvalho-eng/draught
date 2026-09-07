# Getting started

This guide covers the intermediate CLI kernel: building the executable from a source checkout, configuring a local Ollama profile, selecting a model, and running diagnostics. Task and interactive agent execution are not available in this slice.

## 1. Build the executable

The current distribution is built from source and requires the Erlang/OTP and Elixir versions declared by the project.

```shell
mix setup
mix escript.build
./draught --version
```

A one-command installer and packaged release are planned separately.

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

## 3. Check the environment

Run the read-only doctor command from the workspace in which Draught will operate:

```shell
./draught doctor
```

Doctor checks the resolved configuration, workspace access, Ollama reachability, and the Ollama model inventory. OpenAI-compatible connectivity diagnostics are not implemented in this slice, so those profiles return a not-checked provider result. Doctor does not run inference or modify models.

For automation, request one JSON object per output line:

```shell
./draught doctor --output jsonl
```

## 4. Select a model

Ollama discovery examines every installed model and classifies it against Draught's required capabilities. Selection happens after that filtering:

- No installed models produces a provider error.
- Installed models with no compatible entry produce a provider error.
- Exactly one compatible model can be selected automatically by the provider boundary.
- More than one compatible model requires an explicit selection before agent execution can be enabled.
- An explicitly selected missing or incompatible model produces a provider error.

Select a model for one command with `--model`:

```shell
./draught doctor --model qwen3
```

To persist the choice, create the user configuration file described in [Configuration](configuration.md):

```json
{
  "profile": "ollama",
  "model": "qwen3"
}
```

You can also set `DRAUGHT_MODEL=qwen3` for the current environment.

## 5. Current execution boundary

The parser accepts task and interactive forms while the execution path is developed:

```shell
./draught "inspect this workspace"
./draught
```

Both forms currently exit with the execution category and report that agent execution is unavailable. Session creation, resume, web-enabled task execution, and interactive input are not connected in this slice.

See [CLI](cli.md) for command and exit behavior and [Ollama provider](providers/ollama.md) for discovery details.
