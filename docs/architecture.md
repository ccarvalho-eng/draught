# Architecture

Draught is a layered agent runtime built as a functional core with an imperative shell. Domain values, policies, and state transitions are plain data and pure functions. Processes exist only where the runtime needs concurrency, isolation, cancellation, supervision, or ownership of a resource.

## Internal layers

Dependencies point inward. The domain does not know which CLI, model provider, persistence backend, web client, or operating-system adapter is in use.

```mermaid
flowchart TB
  subgraph Interfaces[Interfaces]
    CLI[Agentic CLI]
    API[Elixir API]
  end

  subgraph Application[Application orchestration]
    Commands[Commands]
    Sessions[Session coordinator]
    Runtime[Execution runtime]
  end

  subgraph Domain[Functional domain core]
    Conversation[Conversation values]
    ProviderContracts[Provider contracts]
    ToolContracts[Tool contracts]
    Execution[Execution state transitions]
    Policy[Capability and approval policy]
    Events[Canonical events]
    Errors[Normalized errors]
  end

  subgraph Ports[Effect ports]
    ProviderPort[Provider port]
    ToolPort[Tool port]
    JournalPort[Journal port]
    WorkspacePort[Workspace port]
    WebPort[Web access port]
  end

  subgraph Adapters[Edge adapters]
    Providers[Model providers]
    Tools[Built-in and external tools]
    Journal[Local journal]
    Workspace[Filesystem and process access]
    Web[Search and fetch clients]
  end

  CLI --> Commands
  API --> Commands
  Commands --> Sessions
  Sessions --> Runtime
  Runtime --> Conversation
  Runtime --> ProviderContracts
  Runtime --> ToolContracts
  Runtime --> Execution
  Runtime --> Policy
  Runtime --> Events
  Runtime --> Errors
  Runtime --> ProviderPort
  Runtime --> ToolPort
  Sessions --> JournalPort
  ToolContracts --> WorkspacePort
  Policy --> WebPort
  ProviderPort -. implemented by .-> Providers
  ToolPort -. implemented by .-> Tools
  JournalPort -. implemented by .-> Journal
  WorkspacePort -. implemented by .-> Workspace
  WebPort -. implemented by .-> Web
```

The layers have distinct responsibilities:

| Layer | Owns | Must not own |
| --- | --- | --- |
| Interfaces | Input parsing, rendering, interactive approvals, machine-readable output | Provider payloads, execution decisions, durable state |
| Application orchestration | Session lifecycle, effect sequencing, cancellation, supervision | Provider-specific translation, policy hidden in processes |
| Functional domain core | Canonical values, invariants, policies, state transitions, event semantics | Network, filesystem, environment, clocks, global mutable state |
| Effect ports | Project-owned behaviours for external capabilities | Concrete vendor or operating-system details |
| Edge adapters | Translation and bounded interaction with external systems | Domain policy or cross-adapter coordination |

## Agent execution

The runtime is the only layer that coordinates a model with tools. Model output is treated as a proposal: it cannot directly invoke an effect, grant itself capabilities, or bypass approval policy.

```mermaid
sequenceDiagram
  actor User
  participant Interface as CLI or Elixir API
  participant Session as Session coordinator
  participant Runtime as Bounded runner
  participant Provider as Provider boundary
  participant Policy as Capability and approval policy
  participant Tool as Tool boundary
  participant Journal as Journal boundary

  User->>Interface: Submit intent
  Interface->>Session: Start or continue session
  Session->>Runtime: Execute canonical request
  Runtime->>Provider: Complete canonical request
  Provider-->>Runtime: Final response or tool proposal
  Runtime-->>Session: Publish canonical event
  Session->>Journal: Append canonical session event

  alt Provider returns a final response
    Provider-->>Runtime: Canonical response
    Runtime-->>Session: Complete
  else Provider proposes a tool call
    Runtime->>Policy: Evaluate capability, risk, and approval
    alt Allowed
      Policy-->>Runtime: Approved bounded invocation
      Runtime->>Tool: Execute canonical call
      Tool-->>Runtime: Canonical result
      Runtime->>Provider: Continue with tool result
    else Denied
      Policy-->>Runtime: Normalized policy error
      Runtime->>Provider: Continue with error tool result
    end
  end
```

The application layer may use supervised processes, but it delegates decisions to pure functions. The current runner uses immutable state transitions around supervised provider and tool tasks. The session coordinator owns streaming cancellation and delegates append-only persistence and pure replay to the journal boundary.

The runner reconstructs its request, registry, execution context, policy, and limits before the first provider call. Tool specifications always come from the injected registry. Provider calls and individual tool calls have independent time limits, while one output limit bounds provider responses and tool results. Tool batches execute sequentially in provider declaration order.

```mermaid
stateDiagram-v2
  [*] --> Ready
  Ready --> WaitingProvider: next request within iteration limit
  Ready --> Failed: iteration limit reached
  WaitingProvider --> Completed: final response
  WaitingProvider --> WaitingTools: new tool-call batch
  WaitingProvider --> Failed: provider failure or repeated batch
  WaitingTools --> Ready: one ordered result per call
  Completed --> [*]
  Failed --> [*]
```

## Provider boundary

Providers exchange only canonical Draught values. Provider-specific request bodies, response objects, exceptions, headers, credentials, and stack traces never cross the adapter boundary.

```mermaid
sequenceDiagram
  participant Runtime
  participant Facade as Draught.Provider
  participant Adapter as Provider adapter
  participant Sink as Event consumer

  Runtime->>Facade: stream(adapter, request, sink)
  Facade->>Facade: Validate and reconstruct request
  Facade->>Adapter: stream(canonical request, guarded sink)

  loop Zero or more nonterminal events
    Adapter-->>Facade: Delta or tool-call event
    Facade->>Facade: Validate event
    Facade-->>Sink: Canonical nonterminal event
  end

  Adapter-->>Facade: ok response or normalized error
  Facade->>Facade: Validate result
  Facade-->>Sink: Exactly one completed or failed event
  Facade-->>Runtime: Same canonical result
```

The provider facade owns terminal delivery. An adapter may emit only deltas and tool calls. If the consumer returns `:halt`, the facade aborts adapter emission immediately and returns a canonical cancellation error. This central ownership prevents missing, duplicated, contradictory, or out-of-order terminal events.

Provider adapters are explicitly injected as `{module, config}`. The deterministic fake adapter is an immutable collection of exact request routes, with no process or global state.

## Contracts and trust boundaries

Every value that crosses a boundary is reconstructed through a canonical constructor. Constructors whitelist keys without creating atoms, validate nested structs again, and return structured validation errors. JSON-compatible tool arguments and schemas have bounded depth, collection width, byte size, string size, and string-only object keys.

Normalized failures carry only a closed category, safe code and message, optional hint, and retryability. Expected failures use tagged tuples. Unexpected defects may crash the owning supervised process so the supervision tree can restore a known state.

```mermaid
flowchart LR
  Untrusted[Untrusted external value] --> Decode[Bounded decoding]
  Decode --> Construct[Canonical constructor]
  Construct -->|invalid| SafeError[Structured safe error]
  Construct -->|valid| Policy[Capability and policy checks]
  Policy -->|denied| SafeError
  Policy -->|allowed| Core[Functional domain core]
  Core --> Event[Canonical event]
  Event --> ContentPolicy[CLI or journal content policy]
  Event --> Projection[Bounded metadata projection]
  Projection --> Telemetry[Telemetry]
```

Canonical events provide one vocabulary for the CLI, telemetry, and persistence layers without exposing provider or tool types. Events may contain model text, reasoning, and tool content. The CLI and journal apply explicit display and retention policies, while telemetry receives only derived, bounded measurements and sanitized metadata.

Telemetry instrumentation sits at the application and effect boundaries. Each instrumented operation projects its canonical result into bounded scalar measurements and a closed metadata vocabulary before calling `:telemetry`. Raw domain values do not cross that projection.

```mermaid
flowchart LR
  Boundary[Session, provider, or tool boundary] --> Span[Lifecycle span]
  Span --> Result[Canonical result]
  Result --> Measurements[Bounded measurements]
  Result --> Metadata[Allowlisted metadata]
  Measurements --> Execute[Telemetry event]
  Metadata --> Execute
  Execute --> Consumer[Host-provided consumer]
  Result -. content excluded .-> Execute
```

## Web access and indirect prompt injection

Web access is a separately controlled capability and is disabled by default. Search and fetch permissions are independent. Retrieved content is untrusted data with provenance, never an instruction source or authority grant.

```mermaid
flowchart TB
  Proposal[Model proposes web access] --> Enabled{Capability enabled?}
  Enabled -->|No| Denied[Normalized policy error]
  Enabled -->|Yes| Policy[Evaluate operation and approval policy]
  Policy -->|Denied| Denied
  Policy -->|Allowed| Guard[Bounded isolated web client]
  Guard --> Network[DNS and redirect checks]
  Network --> Content[Size and content-type limits]
  Content --> Provenance[Attach source provenance and untrusted label]
  Provenance --> Context[Provide data to the model]
  Context --> Proposal

  Context -. cannot grant .-> Policy
  Context -. cannot alter .-> Enabled
```

The web adapter must reject private, loopback, link-local, and cloud metadata destinations across initial resolution and redirects. It receives no ambient cookies, credentials, or proxy authority. Classifiers may add warnings or require stronger approval, but they cannot be the sole security boundary.

## State and durability

One session coordinator owns the live lifecycle of a session. Durable history is represented as versioned canonical events and checkpoints rather than process memory. Replay rebuilds state by applying the same pure transitions used during live execution.

Conversation interchange is a projection from canonical history, not a second persistence model. The text encoder applies an explicit retention policy, emits a deterministic authoritative extension, and renders a non-authoritative Markdown view. Import performs bounded decoding and reconstructs the document through the same canonical constructors used by the runtime. Imported artifacts cannot restore execution authority.

The runtime will preserve these invariants:

- One accepted input produces at most one active execution step per session.
- Every stream has exactly one terminal outcome.
- Cancellation is explicit, observable, and cannot be mistaken for success.
- Tool calls are identified so retries and replay can prevent duplicate effects.
- Journal writes contain validated canonical data under an explicit retention policy, never raw provider payloads, tool internals, or credentials.
- A process restart recovers from durable state or fails explicitly; it never guesses hidden state.

## API and dependency rules

- Interfaces call public application APIs and never reach into adapters or process internals.
- Domain code receives explicit values and never reads process dictionaries, application environment, or global state.
- Provider and tool implementations translate external values immediately and keep vendor types inside the adapter.
- Behaviours are used at effect boundaries, not between every pair of pure modules.
- Long-lived processes and production tasks are supervised.
- Private functions follow public functions, and namespaces reflect architectural ownership rather than generic utility groupings.

## Delivery status

Canonical validation, conversation, tool, provider, event, normalized-error, and deterministic-fake contracts are implemented. OpenAI-compatible and Ollama provider integrations, the standard coding tools, approval policy, serialized mutation boundary, bounded subprocess lifecycle, workspace path confinement, application supervision tree, bounded provider-tool runner, supervised session lifecycle, versioned local journals, deterministic text interchange, and sanitized telemetry spans are also present. Attachment bundles, the CLI, and web access remain planned. The diagrams include both implemented and planned boundaries; delivery status identifies which application capabilities are executable.

Tests mirror architectural ownership: pure contracts receive deterministic unit tests, adapters receive shared contract tests, and supervised runtime components receive lifecycle, ordering, cancellation, retry, and recovery tests.
