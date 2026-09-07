# Changelog

All notable changes to Draught will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) after its first public release.

## Unreleased

### Added

- Provider-neutral conversation, tool, request, response, usage, capability, error, and event contracts.
- A validated provider behaviour and facade with guarded synchronous streaming.
- A pure exact-route fake provider for deterministic offline testing.
- Versioned conversation documents with portable attachment descriptors.
- Deterministic Markdown-superset conversation import and export with explicit retention controls.
- Deterministic bounded `.lmmlz` conversation bundles with descriptor-verified attachments.
- A bounded CLI with deterministic configuration, diagnostics, and text or JSONL output.
- Anonymous one-shot CLI tasks executed through temporary supervised sessions with journaling disabled.
