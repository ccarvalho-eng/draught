---
name: elixir-phoenix-hex-publish
description: 'Prepare and publish Hex releases, including versioning, changelog, tags, and release steps.'
metadata:
  short-description: 'Publish a Hex package release'
---

# Hex Publish

This skill prepares and publishes Hex.pm releases for Elixir libraries with a repeatable release workflow.
Use it when the user wants to cut a new version, check whether docs or wiki content need updates, create the release tag, publish to GitHub, or publish to Hex.

## Workflow

1. Build release context.
2. Update release artifacts.
3. Validate locally.
4. Create the git tag and GitHub release.
5. Publish to Hex.

## Build Release Context

- Read `mix.exs`, `CHANGELOG.md`, and `README.md` first.
- Inspect recent tags with `git tag --sort=-creatordate`.
- Inspect the current worktree with `git status --short`.
- Infer the next version only if the intended bump is obvious from the request or existing draft changes. Otherwise ask.
- Check whether the README is outdated relative to the release.
- Check whether the same changes should be reflected in the project wiki. If the repo uses a separate wiki and local wiki content is unavailable, call that out explicitly instead of guessing.

## Update Release Artifacts

- Update `mix.exs` version.
- Update `CHANGELOG.md` using Keep a Changelog style and the release date in `YYYY-MM-DD`. ONLY list final diff with main. e.g. only add fixes if they were broken on main.
- If README content is stale, update it in the same change set.
- If wiki updates are needed but the wiki is not locally available, mention the exact sections that should be updated in the final response.
- Keep release changes focused. Do not mix unrelated refactors into the release commit.

## Validate Locally

- Use project-specific validation commands when present.
- For Phoenix projects, prefer the repo alias if one exists. For Aludel, run `mix precommit` when release edits are complete.
- If dependency state is out of sync, fix that first with the smallest necessary command such as `mix deps.get`.
- Do not tag or publish if validation is failing unless the user explicitly asks to bypass checks.

## Create Release Artifacts

- Confirm the target version before creating release artifacts.
- Create an annotated tag using the repo convention. Prefer `vX.Y.Z` if existing tags use that pattern.
- Push the branch and tag only after local validation passes.
- Create the GitHub release with `gh release create` when GitHub CLI is available and authenticated.
- Use the changelog section for release notes when practical.

## Publish To Hex

- Prefer `HEX_API_KEY=... mix hex.publish --yes` when a valid publish-capable key is available.
- If `mix hex.user whoami` or owner checks fail with `key not authorized for this action`, assume the active credential is insufficient for publish-related user actions and say so clearly.
- If publishing fails because the current account is not an owner of the package, stop and report that the package ownership must be fixed before retrying.
- Distinguish auth failures from package-content issues. Fix doc warnings, changelog, README, or version problems separately from Hex auth.

## Safety Rules

- Never create a tag or GitHub release before the version bump and changelog are committed or at least staged as intended.
- Never publish to Hex before verifying the package version in `mix.exs`.
- Never rewrite or delete unrelated user changes in the worktree.
- Before destructive or irreversible steps, summarize exactly what will be released: version, tag, notable changes, README changes, and whether wiki follow-up is needed.

## Output Expectations

- State the target version and tag explicitly.
- State whether README updates were required.
- State whether the wiki should be updated and why.
- State which validation commands ran and whether they passed.
- State whether the tag, GitHub release, and Hex publish actually happened or were blocked.

## Reference

See `references/release-checklist.md` for the condensed execution checklist.
