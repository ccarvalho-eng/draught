# Draught

Draught is a provider-neutral coding-agent runtime and CLI for Elixir and the BEAM.

The project is in early development. The initial public alpha will connect to Ollama through an OpenAI-compatible provider, run a bounded tool loop, confine filesystem access to a configured workspace, require approval for mutations and commands, and persist resumable local sessions.

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

The [architecture guide](docs/architecture.md) defines Draught's functional core, effect boundaries, and feature-oriented module layout.

The implementation roadmap is tracked through [GitHub milestones](https://github.com/ccarvalho-eng/draught/milestones).
