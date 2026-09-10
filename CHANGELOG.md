# Changelog

All notable changes to Draught will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) after its first public release.

## Unreleased

## 0.1.0-beta.7 - 2026-09-09

### Fixed

- Ollama tool-enabled requests now retry once when a model leaks bare tool-call markup as assistant text. Malformed output is not displayed, executed, or retained in session history.

## 0.1.0-beta.6 - 2026-09-09

### Changed

- Session catalogs right-align numeric references when the visible list contains ten or more entries, matching skill-catalog selection.

### Known limitations

- Native archives built with Burrito 1.6.0 fall back to line-oriented interactive input. Use the escript distribution for cursor editing, command completion, multiline shortcuts, and bracketed paste until [#143](https://github.com/ccarvalho-eng/draught/issues/143) is resolved.

## 0.1.0-beta.5 - 2026-09-09

### Added

- Read-only `/tools` and `/permissions` views for the active built-in catalog, risk admission, approval behavior, workspace, and web capabilities.
- Tab completion for canonical skill names retained after an explicit skill-catalog listing.
- A packaged catalog of 48 Elixir and Phoenix skills with bounded reference material, lowest-precedence overrides, and optional invocation arguments.
- A bounded interactive prompt editor with cursor navigation, multiline input, bracketed paste, and command completion.

### Changed

- Skill discovery is separated into compact `/custom-skills` and `/builtin-skills` catalogs, with bounded descriptions and stable selection from the most recently displayed catalog.
- Interactive multiline input recognizes Shift+Enter when the terminal reports modified keys, with Ctrl+J and Alt+Enter retained as portable fallbacks.

### Fixed

- Built-in skills are embedded in executable code so escript and native distributions can discover them without private-file extraction.
- Native Linux builds avoid unrelated runner package repositories when installing their archive dependency.

## 0.1.0-beta.4 - 2026-09-09

### Added

- Bounded workspace and user `SKILL.md` discovery with explicit `/skills` listing and `/skill REF` invocation through the existing agent-turn authority boundaries.
- An interactive `/clear` command that clears the terminal without changing session state.

### Changed

- Interactive sessions can be named before their first turn, and session lists show one identity using an explicit name, the latest successful user-message preview, or the immutable ID in that order.
- Interactive skills can be selected by list number or exact name, with exact names taking precedence.

## 0.1.0-beta.3 - 2026-09-08

### Added

- Bounded session-list previews derived from the latest successful user message, without replaying journals during catalog discovery.

### Changed

- Interactive help now distinguishes available commands from planned commands and input forms that are not available yet.

### Fixed

- The runner now returns one structured feedback batch when a model repeats identical tool calls, allowing it to reuse the earlier result or change its request before the duplicate guard terminates the turn.

## 0.1.0-beta.2 - 2026-09-08

### Added

- Persistent interactive model selection in the user configuration, with atomic owner-only publication and existing-session binding preservation.
- Tab completion for slash commands and compatible model names already loaded by `/model`.

### Changed

- Human approval waits no longer consume the active tool or interactive-turn execution budget and have no wall-clock deadline.
- Interactive parsing, help output, and terminal completion now share one command catalog.

### Fixed

- Provider failures, tool denials, iteration limits, and other bounded turn failures return control to the interactive prompt instead of closing the session.
- Failed or interrupted turns replay from the last complete conversation boundary without retaining partial model messages.

## 0.1.0-beta.1 - 2026-09-08

### Added

- Provider-neutral conversation, tool, request, response, usage, capability, error, and event contracts.
- A validated provider behaviour and facade with guarded synchronous streaming.
- A pure exact-route fake provider for deterministic offline testing.
- Versioned conversation documents with portable attachment descriptors.
- Deterministic Markdown-superset conversation import and export with explicit retention controls.
- Deterministic bounded `.lmmlz` conversation bundles with descriptor-verified attachments.
- A bounded CLI with deterministic configuration, diagnostics, and text or JSONL output.
- Anonymous one-shot CLI tasks executed through temporary supervised sessions with journaling disabled.
- Durable named CLI sessions with replay-safe provider, model, and capability bindings.
- Bounded user and workspace `AGENTS.md` guidance with stable named-session replay.
- Ordered provider streaming with bounded transient delivery, incremental text and JSONL projection, and a terminal-aware activity indicator.
- Interactive compatible-model listing and pre-persistence model selection for fresh sessions.
- Opt-in guarded page fetching through the CLI web capability.
- A guarded SearXNG JSON search transport with validated result decoding.
- Independent CLI search permission and endpoint configuration with persistent-session capability binding.

### Changed

- Interactive input rails now retain the active model and compact workspace beside the command hints.
- Approval prompts now identify the validated target and reason before requesting input.
