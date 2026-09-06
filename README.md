# Draught

[![CI](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)
[![Elixir: 1.18+](https://img.shields.io/badge/Elixir-1.18%2B-4B275F.svg)](mix.exs)
[![Project status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange.svg)](https://github.com/ccarvalho-eng/draught/milestones)

Draught is a provider-neutral coding-agent runtime and CLI for Elixir and the BEAM.

The project is in pre-alpha development. Its public alpha will provide a polished local-first agent experience: one-command installation, guided provider setup, an OpenAI-compatible Ollama adapter, a bounded tool loop, workspace confinement, explicit approval for risky actions, and resumable local sessions.

## Design goals

- **Simple by default.** A useful first run should not require knowledge of OTP, provider internals, or system dependency management.
- **Generic at the boundary.** Providers and clients exchange stable Draught contracts instead of vendor payloads.
- **Functional at the core.** Domain values and transitions are pure; processes exist only for state, concurrency, isolation, cancellation, or resource ownership.
- **Safe under automation.** Tool access, web access, budgets, timeouts, and mutations are explicit capabilities enforced outside model output.
- **Observable without leakage.** Events support CLI rendering, telemetry, and durable replay without carrying credentials or raw provider internals.

## Project status

| Area | Status |
| --- | --- |
| Project foundation and quality gates | Complete |
| Canonical provider-neutral contracts | Complete |
| OpenAI-compatible and Ollama providers | Planned |
| Workspace-safe tools and bounded runner | Planned |
| Durable sessions and telemetry | Planned |
| Agentic CLI and one-command distribution | Planned |

The [GitHub milestones](https://github.com/ccarvalho-eng/draught/milestones) are the authoritative implementation roadmap. APIs may change before the first tagged alpha.

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

See the [architecture guide](docs/architecture.md) for the internal layers, dependency rules, runtime flows, effect boundaries, and contract invariants.

## Security

Draught treats model output and external content as untrusted. Provider responses do not grant tool permissions; every action remains subject to typed argument validation, capability checks, risk policy, budgets, timeouts, workspace rules, and user approval.

Web access will be disabled by default and explicitly configurable. Search results and fetched pages will retain provenance and remain untrusted data, with bounded content handling and network controls. See the [security policy](SECURITY.md) for the trust model and vulnerability reporting process.

## Development

Install dependencies:

```sh
mix setup
```

Run the fast quality gate:

```sh
mix quality
```

Run the complete pre-commit gate:

```sh
mix precommit
```

The complete gate enforces formatting, warnings, dependency hygiene, compile-cycle detection, every compatible Credo and ExSlop check, zero-clone ExDNA analysis, strict Reach smells, tests and coverage, Dialyzer, documentation coverage, HexDocs generation, and package assembly.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).
