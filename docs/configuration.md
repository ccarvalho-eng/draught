# Configuration

The CLI resolves configuration deterministically from five sources. From highest to lowest precedence, they are:

1. Command-line flags
2. Environment variables
3. Project configuration
4. User configuration
5. Built-in defaults

Precedence does not grant authority. Each source is validated before merging, and less-trusted sources cannot broaden security-sensitive settings.

## Configuration files

The user configuration path is:

- `$XDG_CONFIG_HOME/draught/config.json` when `XDG_CONFIG_HOME` is non-empty.
- `$HOME/.config/draught/config.json` otherwise, when `HOME` is non-empty.
- Disabled when neither location variable is available.

The project configuration path is `.draught/config.json` in the current working directory. Draught does not search parent directories.

Configuration files must be regular files no larger than 65,536 bytes. Symbolic links and other non-regular file types are rejected.

Selecting a model with `/model` in an interactive shell updates the top-level `model` in the user configuration. Draught validates the complete existing file, preserves its other settings, and publishes the replacement atomically with owner-only permissions. A write rejected before publication leaves both the file and shell selection unchanged. If publication succeeds but durability cannot be confirmed, Draught reports the uncertain outcome and leaves the shell selection unchanged; restart before relying on that default. Command-line flags, environment variables, and project configuration still take precedence on later invocations.

## AGENTS.md guidance

Fresh tasks may include coding guidance from two optional files, in this order:

1. `$XDG_CONFIG_HOME/draught/AGENTS.md`, or `$HOME/.config/draught/AGENTS.md` when `XDG_CONFIG_HOME` is unavailable.
2. `AGENTS.md` in the current workspace root.

Draught reads exactly these locations. It does not search workspace ancestors, process includes, or interpolate environment variables in their contents. Later workspace guidance takes precedence over earlier user guidance when the two conflict.

For example, a workspace may define:

```markdown
# Project guidance

- Keep domain decisions in pure modules.
- Run focused tests for every changed boundary.
```

The combined raw contents are limited to 32,768 bytes. Each source must be a regular non-symbolic-link file containing valid UTF-8 without null bytes. Missing and blank files are omitted. Invalid, unsafe, unreadable, or oversized guidance fails before provider execution without echoing its contents.

Guidance is encoded as a bounded data envelope inside the canonical system message. It cannot change configuration, provider or model selection, endpoints, tool registration, risk or approval policy, web capability, workspace confinement, secret handling, or runtime limits. Those controls remain enforced by separate runtime boundaries. The effective guidance is sent to the selected model provider and retained in named-session journals, so `AGENTS.md` must not contain credentials or other secrets.

Anonymous tasks load current guidance for each invocation. A named session loads guidance for its first turn and persists the resulting canonical system message in its journal. Resume uses that recorded message without reading the files again. A named session whose first turn was not durably recorded is not resumed automatically, because it has no authoritative instruction snapshot.

## Built-in configuration

The built-in profile is equivalent to:

```json
{
  "profile": "ollama",
  "web": false,
  "web_search": false,
  "risk": "ask",
  "profiles": {
    "ollama": {
      "provider": "ollama",
      "base_url": "http://localhost:11434"
    }
  }
}
```

Recognized top-level keys are `profile`, `model`, `base_url`, `web`, `web_search`, `web_search_url`, `risk`, and `profiles`. Provider types are `ollama` and `openai-compatible`. Risk values are `deny`, `ask`, and `allow`.

## Task risk modes

Risk mode controls which registered tool risk classes may execute and how effectful tools are approved during an anonymous task:

| Mode | Anonymous task behavior |
| --- | --- |
| `deny` | Only read-risk tools may execute. Write, execute, and network-risk calls are denied by policy. |
| `ask` | Read operations are allowed. Effectful operations require a one-time decision on a text terminal; redirected or JSONL commands return `approval_required` instead. |
| `allow` | All risk classes are admitted and available effectful tools may execute without an approval prompt. |

The default is `ask`. When page fetching or search is enabled, `allow` permits the guarded capability without a terminal prompt; `ask` requires approval for each request. An approved command still retains the ambient network access of the Draught operating-system process. Use `allow` only when the selected workspace and task may perform writes, run commands, or access the web without confirmation. Tool effects completed before a later error, timeout, cancellation, or process interruption remain committed. Anonymous tasks do not roll back those effects and do not retain a task journal. See [Workspace confinement](workspace-confinement.md) for the operating-system boundary.

Risk mode can be set in user configuration or with `DRAUGHT_RISK`. Project configuration may only narrow it to `deny`; there is no command-line risk flag in this slice.

An effective `web` value of `true` registers the guarded `web_fetch` tool. An effective `web_search` value of `true` registers `web_search` when `web_search_url` identifies a valid SearXNG-compatible JSON endpoint. Both permissions default to `false` and are independent.

## User profiles

Profiles may be defined only by built-in defaults or the user configuration file. Profile entries accept `provider`, `base_url`, `credential_env`, and `headers`. `credential_env` is supported only for OpenAI-compatible profiles; credentialed Ollama profiles are rejected because the Ollama adapter does not apply that credential.

This example adds a hosted OpenAI-compatible profile without storing its credential:

```json
{
  "profile": "hosted",
  "model": "MODEL_NAME",
  "profiles": {
    "hosted": {
      "provider": "openai-compatible",
      "base_url": "https://api.example.com/v1",
      "credential_env": "HOSTED_API_KEY"
    }
  }
}
```

Set the declared environment variable separately:

```shell
export HOSTED_API_KEY="..."
```

Credential values are environment-only. A profile declares the exact variable name, which must begin with an uppercase letter and contain only uppercase letters, digits, and underscores. The resolved credential is bound to that selected profile and is not exposed by safe configuration output.

Credential-bound remote profiles require HTTPS. Loopback HTTP endpoints are allowed for local services. A selected credential-bound profile rejects any `--base-url` or `DRAUGHT_BASE_URL` override, including an override that repeats the configured URL. Change the trusted user profile instead.

Sensitive header names, including authorization and API-key headers, are rejected from configuration. Other configured header values are not included in safe status output; only their names are reported.

## Environment variables

The CLI recognizes these configuration variables:

| Variable | Meaning |
| --- | --- |
| `DRAUGHT_PROVIDER` | Selects a profile name. It does not define a provider type or a profile. |
| `DRAUGHT_MODEL` | Selects a model. |
| `DRAUGHT_BASE_URL` | Overrides the endpoint for a profile that is not credential-bound. |
| `DRAUGHT_WEB` | Sets guarded page fetching and must be exactly `true` or `false`. |
| `DRAUGHT_WEB_SEARCH` | Sets guarded search and must be exactly `true` or `false`. |
| `DRAUGHT_WEB_SEARCH_URL` | Sets the explicit SearXNG-compatible JSON search endpoint. |
| `DRAUGHT_RISK` | Sets the risk mode to `deny`, `ask`, or `allow`. |
| `XDG_CONFIG_HOME` | Locates the user configuration directory when non-empty. |
| `HOME` | Provides the fallback user configuration directory. |

Credential variables do not use a fixed Draught name. Each user profile supplies its own `credential_env` name, such as `HOSTED_API_KEY` above.

## Source authority

The source restrictions are part of configuration validation:

- Built-in defaults and user configuration may define profiles.
- Project configuration may select a model, disable page fetching with `"web": false`, disable search with `"web_search": false`, and reduce risk authority with `"risk": "deny"`.
- Project configuration cannot select or define profiles, define endpoints, enable page fetching or search, or set risk to `ask` or `allow`.
- Environment variables and command-line flags may select values but cannot define profiles.
- A top-level endpoint override is accepted only from the environment or command-line flags and only for a profile that is not credential-bound.

A project file that attempts to select a provider profile or broaden web or risk authority is rejected rather than silently ignored. This prevents repository-controlled configuration from activating local, remote, internal, or credential-bound endpoints. Environment variables and command-line flags retain their documented higher precedence when they set the same values.

## Command-line mapping

The command-line configuration flags are:

```text
--provider NAME
--model MODEL
--base-url URL
--web | --no-web
--web-search | --no-web-search
--web-search-url URL
```

`--provider` selects a profile. Define that profile in the user configuration before selecting it. See [CLI](cli.md) for the complete option set and [Getting started](getting-started.md) for a local Ollama example.
