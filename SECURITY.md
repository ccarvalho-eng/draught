# Security policy

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's security advisory interface. Do not open a public issue for a suspected vulnerability.

## Security model

Draught will execute model-requested tools only through explicit tool contracts and approval policies. Workspace confinement limits paths visible to filesystem tools, but it is not an operating-system sandbox. Applications embedding Draught remain responsible for process isolation, operating-system permissions, network policy, and credential scope.

Prompts, source files, command output, credentials, and session contents must not be emitted as telemetry metadata or persisted outside the configured session store by default.

