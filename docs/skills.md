# Skills

Draught skills are reusable, instruction-only Markdown documents. They use a directory-based `SKILL.md` format and run through the ordinary provider-neutral agent turn. A skill does not register code, tools, providers, or commands.

Draught includes 48 built-in Elixir and Phoenix skills covering planning, implementation, review, testing, OTP, Ecto, LiveView, operations, documentation, and related workflows. Run `/skills` to inspect the effective catalog and its source scopes.

## Create a skill

Create one directory whose name matches the skill name:

```text
.draught/
└── skills/
    └── safe-migrations/
        └── SKILL.md
```

The file begins with bounded scalar YAML frontmatter followed by Markdown instructions:

```markdown
---
name: safe-migrations
description: Review database migrations for safe rollout behavior
---

# Safe migrations

Inspect locking, transaction, rollback, and mixed-version behavior before changing a migration.
```

`name` and `description` are required. Names contain at most 64 bytes and use lower-case ASCII letters, digits, and single hyphens. The name must match its parent directory. Descriptions contain at most 1,024 bytes and must fit on one printable line. Additional scalar fields are accepted for format compatibility but do not change Draught behavior. Nested YAML, aliases, tags, interpolation, and executable values are not supported.

## Discovery and precedence

Draught scans one directory level in this order:

1. `<workspace>/.draught/skills`
2. `<workspace>/.agents/skills`
3. `$XDG_CONFIG_HOME/draught/skills`, falling back to `$HOME/.config/draught/skills`
4. `$AGENTS_HOME/skills`, falling back to `$HOME/.agents/skills`
5. The packaged built-in catalog

The first valid definition of a name wins. This lets workspace-specific guidance override shared user and built-in guidance without merging instruction bodies. Duplicate lower-precedence definitions remain inactive.

Each root and the combined catalog are limited to 256 entries. Each `SKILL.md` is limited to 32,768 bytes, and its frontmatter must close within the first 4,096 bytes. Roots, skill directories, and files must be real directories or regular files rather than symbolic links. Invalid entries are skipped and counted without terminating the interactive session.

## Use skills

Inside an interactive session:

```text
/skills
/skill 1 lib/my_app/accounts.ex
```

`/skills` reads a bounded file prefix and displays only names, descriptions, and source scopes; it neither returns nor frames complete instruction bodies. The resulting canonical names are retained as metadata-only completion state, so Tab can complete `/skill NAME` without another filesystem read. `/skill REF [ARGUMENTS]` accepts a one-based list position or exact name, resolves the same precedence order, reads that one complete file, and starts an ordinary agent turn with the selected instructions and optional arguments. Exact names take precedence when a skill has a numeric name. The turn uses the active model and session and follows the same streaming, approval, tool, journal, cancellation, and failure behavior as typed task text.

When a built-in skill is selected, Draught appends its direct Markdown references in deterministic filename order. Reference loading is limited to 16 files, 24,576 bytes per file, and 60,000 bytes for the complete entry plus references. The final framed prompt remains subject to the 65,536-byte skill prompt limit. User and workspace skill references are not loaded automatically.

Skill invocation is explicit in this release. Draught does not infer a skill from a prompt, recursively scan directories, watch for filesystem changes, fetch skills from the network, or load referenced files automatically.

## Security boundary

Skills are guidance, not trusted runtime policy. Draught frames the selected name, description, arguments, and instructions as guidance data before giving them to the model. A skill cannot enable a tool, bypass approval, expand workspace confinement, enable web access, change provider configuration, reveal secrets, or alter runtime limits. Built-in instructions that describe an unavailable integration, process-control feature, or parallel worker must use an available equivalent or report the limitation.

Instructions may ask the agent to use existing tools. Those calls still pass through the canonical registry, schema validation, risk admission, approval policy, workspace confinement, and execution limits. Bundled scripts have no special execution path and must be invoked through the same approved tool boundary as any other command.

Do not store credentials or other secrets in skills. An invoked skill becomes part of the selected session conversation and may be retained in its journal.
