# Draught

[![CI](https://img.shields.io/github/actions/workflow/status/ccarvalho-eng/draught/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-4B275F?style=flat-square&logo=elixir&logoColor=white)](mix.exs)
[![Erlang/OTP](https://img.shields.io/badge/Erlang%2FOTP-27%20%7C%2029-B84444?style=flat-square&logo=erlang&logoColor=white)](.github/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-8CC8E8?style=flat-square&logo=apache&logoColor=white)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)

Draught is a provider-agnostic coding-agent CLI and runtime built with Elixir. Run tasks interactively or headlessly with Ollama or an OpenAI-compatible provider.

## Documentation

### Start here

- [Getting started](docs/getting-started.md)
- [CLI](docs/cli.md)
- [Configuration](docs/configuration.md)

### Design and runtime

- [Architecture](docs/architecture.md)
- [Tool execution](docs/tools.md)
- [Agent runner](docs/runner.md)
- [Session lifecycle](docs/sessions.md)
- [Session journals](docs/session-journals.md)

### Providers and data

- [Ollama provider](docs/providers/ollama.md)
- [Conversation interchange](docs/conversation-interchange.md)

### Operations and security

- [Telemetry](docs/telemetry.md)
- [Web access](docs/web-access.md)
- [Workspace confinement](docs/workspace-confinement.md)

## Built-in agent tools

| Tool | Purpose |
| --- | --- |
| `read_file` | Read a workspace file. |
| `list_directory` | List a workspace directory. |
| `search_workspace` | Search workspace files for literal text. |
| `replace_in_file` | Replace one exact occurrence in a file. |
| `run_command` | Run an executable with arguments. |
| `web_search` | Search through an injected adapter. |
| `web_fetch` | Retrieve text from an HTTP(S) page. |

Tool execution is governed by capability and approval policies. Web tools are opt-in runtime capabilities; CLI web execution is unavailable. See [Tool execution](docs/tools.md) for permissions, limits, and executable dependencies.

## Libraries

| Library | Role |
| --- | --- |
| Owl | Terminal rendering. |
| Req | Provider HTTP requests. |
| Mint | Guarded web fetching. |

Mix installs these libraries with the project dependencies. Workspace file tools are implemented in Elixir and require no external search utility.

## Security

Draught treats model output and external content as untrusted. Workspace confinement is not an operating-system sandbox. Read the [security policy](SECURITY.md) for trust boundaries and private vulnerability reporting.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).
