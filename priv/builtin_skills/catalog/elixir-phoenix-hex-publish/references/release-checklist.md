# Hex Release Checklist

1. Read `mix.exs`, `CHANGELOG.md`, `README.md`, and `git status --short`.
2. Confirm the next version and check recent tags.
3. Update `mix.exs` and `CHANGELOG.md`.
4. Review README for stale screenshots, install steps, provider claims, and release-specific notes.
5. Decide whether the same changes should be reflected in the project wiki.
6. Run local validation, preferring project aliases such as `mix precommit`.
7. Commit release changes if requested or if the workflow requires a clean release commit.
8. Create the annotated tag using the repo convention, usually `vX.Y.Z`.
9. Push branch and tag.
10. Create the GitHub release from the changelog notes.
11. Publish to Hex with a publish-capable key.
12. Report final status, blockers, and any wiki follow-up still needed.
