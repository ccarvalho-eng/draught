# Native executable builds

Draught's native executable includes its Erlang runtime. Users do not need Elixir, Erlang, Zig, or XZ to run the resulting binary. Ollama and model weights remain separate installations. The native executable and escript share the same command implementation, configuration, permission policy, and session storage.

## Install a published release

Choose the target that matches the current system:

| System | Architecture | Target |
| --- | --- | --- |
| macOS | Apple silicon | `macos_arm64` |
| macOS | Intel | `macos_x86_64` |
| Linux | ARM64 | `linux_arm64` |
| Linux | x86_64 | `linux_x86_64` |

Set `TARGET` to that value and download the versioned archive and checksum:

```sh
VERSION=0.1.0-beta.7
TARGET=macos_arm64
BASE_URL="https://github.com/ccarvalho-eng/draught/releases/download/v${VERSION}"
ARCHIVE="draught-${TARGET}.tar.gz"

curl --fail --location --remote-name "${BASE_URL}/${ARCHIVE}"
curl --fail --location --remote-name "${BASE_URL}/${ARCHIVE}.sha256"
```

Verify the downloaded archive on Linux:

```sh
sha256sum --check "${ARCHIVE}.sha256"
```

On macOS, verify it with:

```sh
shasum -a 256 --check "${ARCHIVE}.sha256"
```

Install it into a user-owned executable directory:

```sh
tar -xzf "${ARCHIVE}"
mkdir -p "$HOME/.local/bin"
install -m 755 "draught_${TARGET}" "$HOME/.local/bin/draught"
export PATH="$HOME/.local/bin:$PATH"
draught --version
```

Add the PATH export to the shell startup file if `$HOME/.local/bin` is not already present. Continue with [Getting started](getting-started.md) to configure Ollama and select a model.

The native beta archives currently fall back to line-oriented interactive input because Burrito 1.6.0 does not preserve raw terminal detection for the embedded BEAM process. Ordinary prompts and slash commands remain available. Use the escript distribution for cursor editing, command completion, multiline shortcuts, and bracketed paste until [Draught #143](https://github.com/ccarvalho-eng/draught/issues/143) adopts the upstream fix.

## Build requirements

Native builds use the Elixir and OTP versions in `.tool-versions`, Burrito 1.6.0 from `mix.lock`, Zig 0.16.0, and XZ. Burrito's published 1.6.0 changelog specifies Zig 0.16.0; its README may describe an older Zig version.

The native workflow pins the SHA-256 digest of every ERTS archive and Linux musl loader. It downloads these inputs over HTTPS into an isolated temporary directory and rejects changed bytes before Burrito receives them. The archives' embedded manifests identify OTP 28.4.1 and OpenSSL 3.5.5; each Linux manifest also identifies the matching content-addressed musl loader. A small Burrito build adapter rechecks that loader before embedding it because a local Linux ERTS archive bypasses Burrito's default loader step.

```sh
MIX_TARGET=cli MIX_ENV=prod mix deps.get --check-locked
MIX_TARGET=cli MIX_ENV=prod BURRITO_TARGET=macos_arm64 mix release draught
./burrito_out/draught_macos_arm64 --version
```

Supported build targets are `macos_arm64`, `macos_x86_64`, `linux_arm64`, and `linux_x86_64`. The native workflow executes each artifact on its matching architecture before uploading an archive and SHA-256 checksum. These workflow artifacts are development builds, not published releases. Build and smoke success is required before a target is included in a release.

The `cli` Mix target selects the executable application callback. The default target retains library and escript startup. The executable starts the runtime supervisors and dispatches one invocation synchronously from its callback. The entry point halts with the command's status; it does not return to Burrito's Elixir argument parser or retry the invocation automatically.

## Build an escript from source

The escript path requires the Elixir and Erlang/OTP versions declared by the project:

```sh
git clone https://github.com/ccarvalho-eng/draught.git
cd draught
mix setup
mix escript.build
./draught --version
```

Install the verified escript with the same user-owned path used for the native executable:

```sh
mkdir -p "$HOME/.local/bin"
install -m 755 draught "$HOME/.local/bin/draught"
```

## Maintainer checklist

The repository does not store generated executables. For each pull request and push to `main`, the `Native builds` workflow assembles a new executable from that revision for every supported target. No separate distribution update is needed after an ordinary merge.

Use the workflow's manual dispatch when a branch needs to be rebuilt without a new commit. Select the branch, run the workflow, and confirm that every native matrix job and the shared quality workflow pass. Each native job uploads a target archive together with its SHA-256 checksum. Downloaded artifacts are temporary validation outputs and expire after 14 days.

Before creating a GitHub release:

1. Set the intended version in `mix.exs` and update `CHANGELOG.md`.
2. Confirm the release commit is on `main` and all required quality and native jobs pass for that exact commit.
3. Confirm that the pinned runtime digests and embedded runtime manifests still match the intended OTP, OpenSSL, and musl versions.
4. Download all four target archives and checksum files from the successful native run and verify each checksum.
5. Verify the version and credential-free smoke contract for the extracted artifact on each matching operating system and architecture.
6. Create the version tag from the verified commit, create the GitHub release from that tag, and attach only the verified archives and checksum files.
7. Install through the documented user path in a clean environment and complete the initial Ollama and model-selection steps.

Publishing is a manual maintainer action. A successful workflow does not create a tag, GitHub release, or permanent download automatically.

## Runtime files and configuration

Burrito extracts its bundled runtime on first execution and reuses it on subsequent runs. The runtime cache is distinct from Draught configuration and sessions. `draught maintenance directory` reports the extracted runtime location; `draught maintenance uninstall` removes that runtime payload after confirmation.

Draught reads user configuration from `$XDG_CONFIG_HOME/draught/config.json`, falling back to `$HOME/.config/draught/config.json`. Packaging does not create or overwrite this file. See [Configuration](configuration.md) for file contents and precedence and [Getting started](getting-started.md) for provider setup.

Native builds are not currently signed or notarized. macOS may require explicit approval through its security settings for a downloaded executable. Do not disable Gatekeeper system-wide.

## Upgrade

Download the archive and checksum for the required release and the same operating-system and architecture target as the installed executable. Verify the checksum before extracting or running the replacement. Run the extracted executable with `--version`, then replace the installed `draught` file in the user-owned executable directory. Do not overwrite a working executable until the replacement passes both checks.

A newly installed version extracts its own bundled runtime on first execution. Configuration and named sessions are stored separately and remain available across executable upgrades. Before upgrading across a documented breaking release, review its changelog for configuration or journal compatibility notes.

For an escript built from a source checkout, update the checkout, rebuild the escript, and verify it before replacing the installed copy:

```sh
mix deps.get --check-locked
mix escript.build
./draught --version
install -m 755 draught "$HOME/.local/bin/draught"
```

## Uninstall

Run the executable's maintenance command before deleting it:

```sh
draught maintenance uninstall
rm "$HOME/.local/bin/draught"
```

The maintenance command removes Burrito's extracted runtime payload after confirmation. Removing the executable does not remove Draught configuration or named sessions. Configuration remains under `$XDG_CONFIG_HOME/draught`, falling back to `$HOME/.config/draught`; session state remains under `$XDG_STATE_HOME/draught`, falling back to `$HOME/.local/state/draught`. Inspect and remove those directories separately only when their retained settings and conversation history are no longer needed.

For an escript copied from a source build, remove the copied executable:

```sh
rm "$HOME/.local/bin/draught"
```

## Verification boundaries

The shared credential-free smoke checks cover version and help output, repeated startup, invalid-argument status, and structured diagnostics for an unavailable provider. Native smoke runs without a system BEAM on the executable search path. The same checks run against an escript with its required system runtime available.

These packaging checks do not replace tool execution, interactive terminal, or real-model acceptance tests. Application dependencies, BEAM versions, Zig, ERTS archives, and Linux musl loaders are selected explicitly. Runner operating-system packages are not content-pinned, archive compression is not deterministic, and native builds are therefore not bit-for-bit reproducible.
