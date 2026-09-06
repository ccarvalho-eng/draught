# Contributing to Draught

Contributions are welcome while Draught's initial contracts are being established.

## Development workflow

1. Create a focused branch from `main`.
2. Add tests with behavioral changes.
3. Run `mix quality` during development.
4. Run `mix precommit` before requesting review.
5. Use a Conventional Commit subject for each focused commit.

Keep pull requests narrowly scoped. Separate refactoring from behavioral changes, document security-sensitive decisions, and avoid adding provider-specific types to the core runtime.

Quality checks are enforced. Fix findings at their source; add a narrowly scoped suppression only when the rule is demonstrably incorrect for the code and explain the exception beside it.
