# Draught

[![CI](https://img.shields.io/github/actions/workflow/status/ccarvalho-eng/draught/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-4B275F?style=flat-square&logo=elixir&logoColor=white)](mix.exs)
[![Erlang/OTP](https://img.shields.io/badge/Erlang%2FOTP-27%20%7C%2029-B84444?style=flat-square&logo=erlang&logoColor=white)](.github/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-8CC8E8?style=flat-square&logo=apache&logoColor=white)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)

Draught is a provider-agnostic coding-agent CLI and runtime built with Elixir. Run tasks interactively or headlessly with Ollama or an OpenAI-compatible provider.

## Motivation

[Draught](https://www.merriam-webster.com/dictionary/draught), pronounced "draft", can mean a drink or a dose of medicine, suggesting a measured approach to assistance. The name also echoes "draft": a starting point to examine, revise, and develop into your own solution. Assistance contributes to the work; it does not make the result final or replace your judgment.

### Access without a paid model subscription

Subscription fees and metered APIs can put coding assistance out of reach. Draught aims to make agentic work accessible to developers who cannot afford premium tools, using freely available models on their own machines through Ollama. Local inference avoids per-request API charges, but still requires suitable hardware, electricity, and a model whose license permits the intended use. Provider-agnostic interfaces leave that choice with the user.

### An OTP foundation for agents

The architectural inspiration is the actor model and [OTP supervision](https://www.erlang.org/doc/system/sup_princ.html): keep conversation state separate from the work performed on its behalf. Sessions own their lifecycle; model requests and tool calls execute in isolated, supervised tasks with explicit timeouts and cancellation. Pure functions define state transitions and permission policies. This separation provides failure boundaries without making the model responsible for runtime safety. Restarting a process is not permission to repeat an edit or command. See [Architecture](docs/architecture.md) for the supervision and execution contracts.

### An opportunity to stay engaged

Local models may need more guidance and checking than top-tier hosted models, depending on the model and task. If you work with one, consider using that extra involvement as an opportunity to learn: investigate why a suggestion fails, consult the documentation, ask for explanations, and test your own understanding. More intervention can be frustrating, but it can also leave room for hands-on practice instead of delegating the entire problem.

Research offers a reason to value that engagement:

- [Shen and Tamkin (2026), *How AI Impacts Skill Formation*](https://arxiv.org/abs/2601.20245), a preprint, reports lower immediate skill scores with AI assistance in a randomized study of 52 developers learning an unfamiliar library. Exploratory analysis associated explanation-seeking and conceptual questions with better learning outcomes than delegation-heavy use.
- [Bastani et al. (2025), *Generative AI without guardrails can harm learning*](https://doi.org/10.1073/pnas.2422633122), published in PNAS, found worse subsequent unaided performance with an unrestricted AI tutor in high-school mathematics; learning-oriented safeguards largely mitigated that effect.

These studies concern learning in specific settings. They do not establish long-term cognitive effects or show that weaker models teach better. Draught has not been evaluated for learning outcomes.

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
| [Owl](https://github.com/fuelen/owl) | Terminal rendering. |
| [Req](https://github.com/wojtekmach/req) | Provider HTTP requests. |
| [Mint](https://github.com/elixir-mint/mint) | Guarded web fetching. |

Mix installs these libraries with the project dependencies. Workspace file tools are implemented in Elixir and require no external search utility.

## Security

Draught treats model output and external content as untrusted. Workspace confinement is not an operating-system sandbox. Read the [security policy](SECURITY.md) for trust boundaries and private vulnerability reporting.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).
