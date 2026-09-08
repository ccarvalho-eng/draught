# Native executable builds

Draught's native executable includes its Erlang runtime. Users do not need Elixir, Erlang, Zig, or XZ to run the resulting binary. Ollama and model weights remain separate installations. The native executable and escript share the same command implementation, configuration, permission policy, and session storage.

## Build requirements

Native builds use the Elixir and OTP versions in `.tool-versions`, Burrito 1.6.0 from `mix.lock`, Zig 0.16.0, and XZ. Burrito's published 1.6.0 changelog specifies Zig 0.16.0; its README may describe an older Zig version.

```sh
MIX_TARGET=cli MIX_ENV=prod mix deps.get --check-locked
MIX_TARGET=cli MIX_ENV=prod BURRITO_TARGET=macos_arm64 mix release draught
./burrito_out/draught_macos_arm64 --version
```

Supported build targets are `macos_arm64`, `macos_x86_64`, `linux_arm64`, and `linux_x86_64`. The native workflow executes each artifact on its matching architecture before uploading an archive and SHA-256 checksum. These workflow artifacts are development builds, not published releases. Build and smoke success is required before a target is included in a release.

The `cli` Mix target selects the executable application callback. The default target retains library and escript startup. The executable starts the runtime supervisors and dispatches one invocation synchronously from its callback. The entry point halts with the command's status; it does not return to Burrito's Elixir argument parser or retry the invocation automatically.

## Maintainer checklist

The repository does not store generated executables. For each pull request and push to `main`, the `Native builds` workflow assembles a new executable from that revision for every supported target. No separate distribution update is needed after an ordinary merge.

Use the workflow's manual dispatch when a branch needs to be rebuilt without a new commit. Select the branch, run the workflow, and confirm that every native matrix job and the shared quality workflow pass. Each native job uploads a target archive together with its SHA-256 checksum. Downloaded artifacts are temporary validation outputs and expire after 14 days.

Before creating a GitHub release:

1. Set the intended version in `mix.exs` and update `CHANGELOG.md`.
2. Confirm the release commit is on `main` and all required quality and native jobs pass for that exact commit.
3. Resolve every limitation identified under [Verification boundaries](#verification-boundaries), including the upstream runtime provenance gate.
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

If the escript was installed from Hex through Mix, fetch the intended package version and replace the registered command explicitly:

```sh
mix escript.install hex draught VERSION --force
draught --version
```

`VERSION` is the exact published package version. Escript installation requires a compatible local Elixir and Erlang toolchain.

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

For an escript installed from Hex through Mix, use:

```sh
mix escript.uninstall draught
```

## Verification boundaries

The shared credential-free smoke checks cover version and help output, repeated startup, invalid-argument status, and structured diagnostics for an unavailable provider. Native smoke runs without a system BEAM on the executable search path. The same checks run against an escript with its required system runtime available.

These packaging checks do not replace tool execution, interactive terminal, or real-model acceptance tests. Application dependencies, BEAM versions, and Zig are selected explicitly. Runner packages and upstream ERTS payloads are not currently digest-pinned, so builds are not bit-for-bit reproducible and development artifacts are not release-ready without an additional provenance gate.
