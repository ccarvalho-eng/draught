# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's security advisory interface. Do not open a public issue for a suspected vulnerability.

## Security model

Draught will execute model-requested tools only through explicit tool contracts and approval policies. Workspace confinement limits paths visible to filesystem tools, but it is not an operating-system sandbox. Applications embedding Draught remain responsible for process isolation, operating-system permissions, network policy, and credential scope.

Prompts, source files, command output, credentials, and session contents must not be emitted as telemetry metadata or persisted outside the configured session store by default.

### Trust boundaries

- User prompts, model output, provider payloads, files, command output, tool results, search results, and fetched pages are untrusted inputs.
- Provider adapters translate external values into canonical contracts and must not expose credentials, headers, raw exceptions, stack traces, or vendor payloads.
- A model can propose a typed tool call but cannot grant itself a capability, change policy, bypass validation, or approve an action.
- Persistent session data retains its source and trust classification. Replaying a session does not promote external content into trusted instructions.

### Web access and prompt injection

Web search and page fetching are opt-in capabilities and remain disabled unless the effective configuration enables them. Search and fetch permissions are independent. The guarded web core enforces capability, result, provenance, and fetch-transport boundaries; CLI controls are not yet available. Every request and redirect handled by the included fetch transport must pass network policy, address validation, content-type checks, size limits, redirect limits, and time budgets.

Fetched content is data, not instruction. Prompt-injection detection may provide warnings, but it is not an authorization boundary. Draught relies on least privilege, isolated clients without ambient credentials, typed tool calls, deterministic policy checks, human approval for risky actions, and bounded agent execution.

### Non-goals

Draught does not treat system prompts as secret enforcement mechanisms and does not claim that content filtering can eliminate prompt injection. Workspace confinement alone does not provide process, kernel, container, or network isolation.
