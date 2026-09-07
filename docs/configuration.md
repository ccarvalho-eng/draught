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

## Built-in configuration

The built-in profile is equivalent to:

```json
{
  "profile": "ollama",
  "web": false,
  "risk": "ask",
  "profiles": {
    "ollama": {
      "provider": "ollama",
      "base_url": "http://localhost:11434"
    }
  }
}
```

Recognized top-level keys are `profile`, `model`, `base_url`, `web`, `risk`, and `profiles`. Provider types are `ollama` and `openai-compatible`. Risk values are `deny`, `ask`, and `allow`.

## Task risk modes

Risk mode controls which registered tool risk classes may execute and how effectful tools are approved during an anonymous task:

| Mode | Anonymous task behavior |
| --- | --- |
| `deny` | Only read-risk tools may execute. Write, execute, and network-risk calls are denied by policy. |
| `ask` | All risk classes reach the approval policy. Read operations are allowed; effectful operations return an approval-required result because the anonymous command has no interactive approval prompt. |
| `allow` | All risk classes are admitted and available effectful tools may execute without an approval prompt. |

The default is `ask`. Web tools are not registered in the current one-shot CLI, so `allow` does not add the guarded web capability. An approved command still retains the ambient network access of the Draught operating-system process. Use `allow` only when the selected workspace and task may perform writes or run commands without confirmation. Tool effects completed before a later error, timeout, cancellation, or process interruption remain committed. Anonymous tasks do not roll back those effects and do not retain a task journal. See [Workspace confinement](workspace-confinement.md) for the operating-system boundary.

Risk mode can be set in user configuration or with `DRAUGHT_RISK`. Project configuration may only narrow it to `deny`; there is no command-line risk flag in this slice.

An effective `web` value of `true` is retained in configuration and status output, but an anonymous task rejects it with `web_execution_unavailable` until a search adapter is configured. `web: false` remains the default.

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
| `DRAUGHT_WEB` | Sets web access and must be exactly `true` or `false`. |
| `DRAUGHT_RISK` | Sets the risk mode to `deny`, `ask`, or `allow`. |
| `XDG_CONFIG_HOME` | Locates the user configuration directory when non-empty. |
| `HOME` | Provides the fallback user configuration directory. |

Credential variables do not use a fixed Draught name. Each user profile supplies its own `credential_env` name, such as `HOSTED_API_KEY` above.

## Source authority

The source restrictions are part of configuration validation:

- Built-in defaults and user configuration may define profiles.
- Project configuration may select a model, disable web access with `"web": false`, and reduce risk authority with `"risk": "deny"`.
- Project configuration cannot select or define profiles, define endpoints, enable web access, or set risk to `ask` or `allow`.
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
```

`--provider` selects a profile. Define that profile in the user configuration before selecting it. See [CLI](cli.md) for the complete option set and [Getting started](getting-started.md) for a local Ollama example.
