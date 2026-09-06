# Architecture

Draught uses a functional core with an imperative shell. Domain values and state transitions are plain data and pure functions. Processes exist only for runtime state, concurrency, isolation, cancellation, or resource ownership.

## Module boundaries

Each feature owns a focused namespace and directory. Provider implementations receive their own subdirectory so adapter details cannot leak into the core.

```text
lib/draught/
|-- conversation/           messages, content parts, roles, and usage values
|-- provider.ex             provider behaviour and public contracts
|-- provider/
|   |-- capabilities.ex     provider capability values and validation
|   |-- request.ex          canonical provider request
|   |-- response.ex         canonical provider response
|   |-- open_ai/            OpenAI-compatible transport and translation
|   `-- ollama/             Ollama configuration and capability presets
|-- execution/              pure provider-tool state transitions and limits
|-- session/                lifecycle, events, streaming, and cancellation
|-- tool.ex                 tool behaviour and public contracts
|-- tool/
|   |-- call.ex             canonical tool invocation
|   |-- result.ex           canonical tool result
|   |-- built_in/           read, search, patch, and command implementations
|   `-- approval/           risk classification and approval policy
|-- workspace/              canonical path resolution and confinement
|-- journal/                versioned local events, checkpoints, and replay
|-- telemetry/              sanitized event definitions and emission
`-- cli/                    argument parsing, rendering, and user interaction
```

Directories are created when their first real module is introduced. Empty namespaces and generic `Utils`, `Helpers`, or `Common` modules are not used.

Directory and module namespaces stay aligned. Canonical values use contextual names such as `Draught.Conversation.Message`, `Draught.Provider.Capabilities`, `Draught.Tool.Call`, and `Draught.Session.Event`; flat names such as `Draught.Message`, `Draught.ToolCall`, and `Draught.Event` are avoided.

## Dependency direction

- `Draught` is the narrow application-facing facade.
- The CLI calls public Draught APIs and never reaches into adapters or process internals.
- Conversation and contract modules depend only on closely related value modules and the Elixir standard library.
- Execution transitions depend on canonical context contracts, not provider or tool implementations.
- Providers and tools implement behaviours defined at the boundary and translate external values immediately.
- Session processes coordinate effects but delegate decisions and transitions to pure functions.
- Req, Jason, filesystem, operating-system, and persistence APIs stay behind project-owned adapters.

Dependencies point inward toward stable contracts. A provider may depend on `Draught.Provider` and domain values; the domain never depends on a provider.

## API rules

- Prefer one module per file and one reason to change per module.
- Keep public APIs small; make implementation modules private by convention unless callers need a stable contract.
- Represent expected failures with tagged tuples and unexpected faults with process exits.
- Pass explicit data through pure functions instead of reading process dictionaries, application environment, or global state inside the core.
- Use behaviours at effect boundaries, not between every pair of pure modules.
- Keep provider-specific structs, payloads, and errors inside that provider's namespace.
- Add a process only when the runtime needs state, concurrency, isolation, cancellation, or supervision.
- Supervise every long-lived process and every production task.

Tests mirror the source layout. Pure modules receive deterministic unit tests; adapters receive contract tests; process modules receive lifecycle and failure tests.
