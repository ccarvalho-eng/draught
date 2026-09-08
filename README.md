# Draught

[![CI](https://img.shields.io/github/actions/workflow/status/ccarvalho-eng/draught/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-4B275F?style=flat-square&logo=elixir&logoColor=white)](mix.exs)
[![Erlang/OTP](https://img.shields.io/badge/Erlang%2FOTP-27%20%7C%2029-D97B80?style=flat-square&logo=erlang&logoColor=white)](.github/workflows/ci.yml)
[![Coverage](https://img.shields.io/badge/Coverage-90%25%2B-2E7D32?style=flat-square)](mix.exs)
[![Doc coverage](https://img.shields.io/badge/Doc%20coverage-100%25-1565C0?style=flat-square)](mix.exs)
[![License](https://img.shields.io/badge/License-Apache--2.0-orange?style=flat-square&logo=apache&logoColor=white)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)

Draught is a provider-neutral coding-agent runtime and CLI for Elixir and the BEAM.

## Documentation

See the [documentation index](docs/index.md) for setup, CLI, architecture, providers, runtime, sessions, tools, web access, and security.

## Design constraints

| Concern | Constraint |
| --- | --- |
| Setup | The first-run path must not require knowledge of OTP, provider internals, or system dependency management. |
| Provider integration | Providers and clients exchange Draught contracts instead of vendor payloads. |
| Local models | Agentic work must be available through locally hosted models without requiring a paid model API. |
| Runtime design | Domain values and transitions are pure. Processes are limited to state, concurrency, isolation, cancellation, or resource ownership. |
| Authorization | Tool access, web access, budgets, timeouts, and mutations are explicit capabilities enforced independently of model output. |
| Observability | Telemetry excludes credentials, message content, and raw provider values. Content-bearing events are handled by explicit CLI and journal policies. |

## Provider contracts

Draught keeps conversations and providers independent. Applications construct canonical messages and requests, then inject an adapter explicitly:

```elixir
{:ok, user} = Draught.Conversation.user("Explain this project")
{:ok, request} = Draught.Provider.Request.new(model: "local-model", messages: [user])
{:ok, assistant} = Draught.Conversation.assistant(content: "A provider-neutral agent runtime.")
{:ok, response} = Draught.Provider.Response.new(message: assistant, finish_reason: :stop)

{:ok, fake} =
  Draught.Provider.Fake.new(
    completions: [%{request: request, response: response}]
  )

Draught.Provider.complete({Draught.Provider.Fake, fake}, request)
# => {:ok, response}
```

The included fake is pure and route-based. It provides deterministic offline tests without processes, global configuration, or network access.

## Built-in agent tools

| Tool | Risk | Purpose |
| --- | --- | --- |
| `read_file` | Read | Read a confined UTF-8 workspace file. |
| `list_directory` | Read | List bounded entries in a confined workspace directory. |
| `search_workspace` | Read | Search workspace text under file, match, depth, and byte limits. |
| `replace_in_file` | Write | Replace one exact occurrence through serialized atomic mutation. |
| `run_command` | Execute | Run an executable with an argument vector, scrubbed environment, timeout, cancellation, and bounded output. |
| `web_search` | Network | Search through an explicitly enabled adapter and retain untrusted provenance. |
| `web_fetch` | Network | Fetch bounded HTTP(S) text under redirect, address, and egress controls. |

Web tools are absent from the default registry. Write, execute, and network operations remain subject to the configured risk and approval policies. See the [tool execution guide](docs/tools.md) for schemas, limits, and execution boundaries.

Workspace file tools are implemented in Elixir and require no external utilities. `run_command` uses executables available through its configured path. Draught does not install or bundle ripgrep (`rg`), `fzf`, or `pgcli`.

Terminal rendering uses Owl, provider HTTP requests use Req, and guarded web fetching uses Mint. These libraries are installed by Mix with the project dependencies.

## Security

Draught treats model output and external content as untrusted. Provider responses do not grant tool permissions; every action remains subject to typed argument validation, capability checks, risk policy, budgets, timeouts, workspace rules, and user approval.

Web access is disabled by default and explicitly configurable. Search results and fetched pages retain sanitized provenance and remain untrusted data, with bounded content handling and network controls. The current one-shot CLI rejects enabled web execution until a search adapter is connected. See the [web access guide](docs/web-access.md) for controls and limitations, and the [security policy](SECURITY.md) for the trust model and vulnerability reporting process.

## Development

Install dependencies:

```sh
mix setup
```

Run the development quality gate:

```sh
mix quality
```

Run the complete pre-commit gate:

```sh
mix precommit
```

The pre-commit gate runs formatting, warnings, dependency hygiene, compile-cycle detection, every compatible Credo and ExSlop check, zero-clone ExDNA analysis, strict Reach smells, tests and coverage, Dialyzer, documentation coverage, HexDocs generation, and package assembly.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).
