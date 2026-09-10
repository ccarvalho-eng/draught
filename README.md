# Draught

[![CI](https://img.shields.io/github/actions/workflow/status/ccarvalho-eng/draught/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-4B275F?style=flat-square&logo=elixir&logoColor=white)](mix.exs)
[![Erlang/OTP](https://img.shields.io/badge/Erlang%2FOTP-27%20%7C%2029-B84444?style=flat-square&logo=erlang&logoColor=white)](.github/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-8CC8E8?style=flat-square&logo=apache&logoColor=white)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)

Draught is a provider-agnostic coding-agent CLI and runtime built with Elixir. Run tasks interactively or headlessly with Ollama or an OpenAI-compatible provider.

<div align="left">
  <img width="700" src="https://github.com/user-attachments/assets/d8ce67b6-40f3-4c7b-bb06-7f3d5aaee273" />
</div>

## Installation

Download the archive for the current operating system and architecture from the `v0.1.0-beta.8` release. The available targets are:

| System | Architecture | Target |
| --- | --- | --- |
| macOS | Apple silicon | `macos_arm64` |
| macOS | Intel | `macos_x86_64` |
| Linux | ARM64 | `linux_arm64` |
| Linux | x86_64 | `linux_x86_64` |

Set `TARGET` to the matching value, then verify and install the archive:

```shell
VERSION=0.1.0-beta.8
TARGET=macos_arm64
BASE_URL="https://github.com/ccarvalho-eng/draught/releases/download/v${VERSION}"
ARCHIVE="draught-${TARGET}.tar.gz"

curl --fail --location --remote-name "${BASE_URL}/${ARCHIVE}"
curl --fail --location --remote-name "${BASE_URL}/${ARCHIVE}.sha256"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum --check "${ARCHIVE}.sha256"
else
  shasum -a 256 --check "${ARCHIVE}.sha256"
fi

tar -xzf "${ARCHIVE}"
mkdir -p "$HOME/.local/bin"
install -m 755 "draught_${TARGET}" "$HOME/.local/bin/draught"
"$HOME/.local/bin/draught" --version
```

The native executable includes its Erlang runtime; Elixir and Erlang/OTP are not required. Add `$HOME/.local/bin` to `PATH` to invoke the command as `draught`. See [Getting started](docs/getting-started.md) for Ollama and model setup, and [Distribution](docs/distribution.md) for source builds, upgrades, and uninstalling.

Native beta archives currently use line-oriented interactive input because of an [upstream Burrito terminal issue](https://github.com/burrito-elixir/burrito/issues/234). Build or install the escript when cursor editing, command completion, multiline shortcuts, or bracketed paste is required. Draught tracks adoption of the upstream fix in [#143](https://github.com/ccarvalho-eng/draught/issues/143).

## Motivation

[Draught](https://www.merriam-webster.com/dictionary/draught), pronounced "draft", can mean a drink or a dose of medicine, suggesting a measured approach to assistance. The name also echoes "draft": a starting point to examine, revise, and develop into your own solution. Assistance contributes to the work; it does not make the result final or replace your judgment.

### Local control and privacy

Running a model locally can keep prompts, source code, and model responses on the user's machine instead of sending them to a hosted inference service. Draught supports that workflow through Ollama while keeping the provider boundary open for other deployments. Privacy still depends on the selected provider and enabled tools: web access and remote integrations can transmit data outside the machine, so those capabilities remain explicit.

### An OTP foundation for agents

The architectural inspiration is the actor model and [OTP supervision](https://www.erlang.org/doc/system/sup_princ.html): keep conversation state separate from the work performed on its behalf. Sessions own their lifecycle; model requests and tool calls execute in isolated, supervised tasks with explicit timeouts and cancellation. Pure functions define state transitions and permission policies. This separation provides failure boundaries without making the model responsible for runtime safety. Restarting a process is not permission to repeat an edit or command. See [Architecture](docs/architecture.md) for the supervision and execution contracts.

Draught was also informed by [Yoke](https://github.com/Oeditus/yoke), formerly DSH, and its exploration of an actor-driven harness in Elixir. Thanks to Oeditus for publishing the project and its design discussion openly.

### An opportunity to stay engaged

Local models may need more guidance and checking than top-tier hosted models, depending on the model and task. If you work with one, consider using that extra involvement as an opportunity to learn: investigate why a suggestion fails, consult the documentation, ask for explanations, and test your own understanding. More intervention can be frustrating, but it can also leave room for hands-on practice instead of delegating the entire problem.

Research offers a reason to value that engagement:

- [Shen and Tamkin (2026), *How AI Impacts Skill Formation*](https://arxiv.org/abs/2601.20245), a preprint, reports lower immediate skill scores with AI assistance in a randomized study of 52 developers learning an unfamiliar library. Exploratory analysis associated explanation-seeking and conceptual questions with better learning outcomes than delegation-heavy use.
- [Bastani et al. (2025), *Generative AI without guardrails can harm learning*](https://doi.org/10.1073/pnas.2422633122), published in PNAS, found worse subsequent unaided performance with an unrestricted AI tutor in high-school mathematics; learning-oriented safeguards largely mitigated that effect.

These studies concern learning in specific settings. They do not establish long-term cognitive effects or show that weaker models teach better. Draught has not been evaluated for learning outcomes.

## Documentation

Read [Getting started](docs/getting-started.md) for setup, or browse the [documentation index](docs/index.md) for CLI, provider, architecture, and security guides.

## Security

Draught treats model output and external content as untrusted. Workspace confinement is not an operating-system sandbox. Read the [security policy](SECURITY.md) for trust boundaries and private vulnerability reporting.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).
