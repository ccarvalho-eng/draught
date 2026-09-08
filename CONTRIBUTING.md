# Contributing to Draught

Contributions are welcome while Draught's initial contracts are being established.

Before proposing a change, review the relevant [roadmap milestone](https://github.com/ccarvalho-eng/draught/milestones) and the [architecture guide](docs/architecture.md). Open an issue first for new public APIs, architectural changes, provider contracts, persistence formats, or security-policy changes.

## Setup and quality checks

Install dependencies from a source checkout:

```sh
mix setup
```

Run `mix quality` during development and `mix precommit` before requesting review. The complete gate checks formatting, compilation warnings, dependency hygiene, compile cycles, compatible Credo and ExSlop rules, zero-clone ExDNA analysis, strict Reach smells, tests and coverage, Dialyzer, documentation coverage, HexDocs generation, and package assembly.

## Development workflow

1. Create a focused branch from `main`.
2. Add tests with behavioral changes.
3. Run `mix quality` during development.
4. Run `mix precommit` before requesting review.
5. Use a Conventional Commit subject for each focused commit.

Keep pull requests narrowly scoped. Separate refactoring from behavioral changes, document security-sensitive decisions, and avoid adding provider-specific types to the core runtime.

Quality checks are enforced. Fix findings at their source; add a narrowly scoped suppression only when the rule is demonstrably incorrect for the code and explain the exception beside it.

## Native distribution

Native executables are generated artifacts and are not committed. The `Native builds` workflow rebuilds and smokes all supported targets for every pull request and every push to `main`, so an ordinary source change does not require a separate Burrito update.

Pay particular attention to the native results when changing application startup, CLI argument handling, dependencies, release configuration, runtime file locations, or `scripts/smoke-cli.sh`. To validate a branch again without changing it, open `Native builds` under GitHub Actions, choose **Run workflow**, select the branch, and start the run. Each successful matrix job provides one target archive and its SHA-256 checksum for 14 days.

Do not treat workflow artifacts as a public release. Follow the maintainer checklist in [Native executable builds](docs/distribution.md#maintainer-checklist) before publishing them.

## Architecture expectations

- Keep directory paths and module namespaces aligned.
- Put each provider, tool family, and feature context in its own folder.
- Prefer pure functions and immutable values; introduce processes only for runtime ownership or concurrency.
- Translate external values at the boundary and keep vendor-specific payloads inside their adapter namespace.
- Return structured expected failures and preserve supervision for unexpected faults.
- Add deterministic tests for valid input, malformed input, relational invariants, and boundary failures.

## Security changes

Changes involving tools, command execution, filesystem access, networking, prompt construction, approvals, persistence, or credentials must describe their trust boundaries and failure behavior. Never include real credentials, private prompts, local machine details, or sensitive payloads in tests, fixtures, issues, or pull requests.
