---
name: elixir-phoenix-hexdocs-fetcher
description: 'Fetch and convert HexDocs pages for focused library lookups.'
metadata:
  short-description: 'Fetch focused HexDocs content'
---

# HexDocs Fetcher

Efficiently fetch Elixir library documentation from hexdocs.pm using Draught web tools (`web.search_query` and `web.open`).

## Usage

When researching libraries:

```text
# Fetch library overview (known URL)
web.open("https://hexdocs.pm/oban")

# Fetch specific module docs
web.open("https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html")

# Discover docs URL first, then open it
web.search_query("Oban.Worker site:hexdocs.pm")
web.open("{selected_result_url}")
```

## Token Efficiency

Draught web tools extract page content so you can summarize key sections quickly:

| Source | Raw HTML | With Draught web tools | Benefit |
|--------|----------|----------------------|---------|
| HexDocs page | ~80k tokens | ~15k tokens | **80% reduction** |
| Phoenix docs | ~120k tokens | ~25k tokens | **79% reduction** |
| README | ~20k tokens | ~8k tokens | **60% reduction** |

## Integration with hex-library-researcher

When evaluating libraries, fetch docs efficiently:

```text
web.open("https://hexdocs.pm/oban")
```

## Common HexDocs URLs

```text
# Library overview
https://hexdocs.pm/{library}

# Module documentation
https://hexdocs.pm/{library}/{Module}.html
https://hexdocs.pm/{library}/{Module.Submodule}.html

# Guides
https://hexdocs.pm/{library}/guides.html
https://hexdocs.pm/{library}/{guide-name}.html

# API reference
https://hexdocs.pm/{library}/api-reference.html
```

## Extraction Strategies

Use focused extraction goals for better summaries:

```text
# For API docs
Extract all public function docs with @spec and examples.

# For guides
Extract the complete guide content preserving code examples.

# For troubleshooting
Extract troubleshooting sections, common errors, and FAQs.

# For configuration
Extract configuration options and their defaults.
```

## Caching

Draught may cache repeated fetches internally. Still prefer reusing prior notes within the same plan/research folder.

For longer persistence, save summaries under planning artifacts:

```text
.draught/plans/{slug}/research/docs-oban.md
```

## Tidewave Alternative

If Tidewave MCP is available, prefer `mcp__tidewave__get_docs` for exact version-matched documentation:

```text
mcp__tidewave__get_docs(module: "Oban.Worker")
```

This fetches docs for the exact version in your `mix.lock`.

## Iron Laws

1. **NEVER fetch entire HexDocs sites** — always target specific modules or guides
2. **Use focused extraction goals** — generic fetches waste tokens; specify what to extract
3. **Prefer Tidewave when available** — exact version match beats generic hexdocs.pm
