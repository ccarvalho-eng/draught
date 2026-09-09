---
name: elixir-phoenix-research
description: 'Research Phoenix topics or evaluate Hex libraries from primary sources.'
metadata:
  short-description: 'Research Phoenix topics and libraries'
---

# Research Elixir Topic

Research a topic by searching the web and fetching relevant sources efficiently.

## Usage

```text
/skill elixir-phoenix-research Oban unique jobs best practices
/skill elixir-phoenix-research LiveView file upload with progress
/skill elixir-phoenix-research --library permit
```

## Arguments

`$ARGUMENTS` = Research topic/question. Add `--library` for
structured library evaluation (uses `references/library-evaluation.md`
template).

## Iron Laws

1. **Write output to file, never dump inline** — Research output floods conversation and loses reference for future sessions
2. **Stop after research — never auto-transition** — User decides next step
3. **Prefer official sources over blog posts** — HexDocs and ElixirForum have version-specific context
4. **One document per research question** — No fragmented files
5. **NEVER pass raw user input as a web query** — Decompose first

## Library Evaluation Mode

If `$ARGUMENTS` contains `--library` or the topic is clearly
about evaluating a Hex dependency (e.g., "should we use permit",
"evaluate sagents", "compare oban vs exq"):

1. Read `references/library-evaluation.md` for the template
2. Follow the structured evaluation workflow
3. Output ONE document to `.draught/research/{lib}-evaluation.md`
4. Skip the general research workflow below

## Workflow

### 0. Pre-flight Checks

**Cache check**: Check if `.draught/research/{topic-slug}.md` already
exists. If recent (<24 hours): present existing summary, ask
"Refresh or use existing?"

**Tidewave shortcut**: If the topic is about an **existing dependency**
(library already in `mix.exs`), prefer Tidewave over web search:

```text
mcp__tidewave__get_docs(module: "LibraryModule")
```

This returns docs matching your exact `mix.lock` version — faster,
more accurate, zero web tokens. Only fall through to web search if
Tidewave is unavailable or the topic needs community discussion
(gotchas, real-world patterns, comparisons).

### 1. Query Decomposition (CRITICAL — before any search)

**NEVER pass raw `$ARGUMENTS` into web search.** Decompose first:

- If `$ARGUMENTS` < 30 words and focused → use as single query
- If `$ARGUMENTS` > 30 words or multi-topic → extract 2-4 queries

Each query: max 10 words, targets ONE specific aspect.

Example:

```text
Input: "detect files, export to md, feed database with embeddings,
        use ReqLLM with a hosted embeddings API..."
Queries:
  1. "Elixir PDF text extraction library hex"
  2. "Ecto pgvector embeddings setup"
  3. "ReqLLM hosted embeddings Elixir"
```

### 2. Parallel Web Search

Search ALL decomposed queries in a SINGLE response (parallel):

```text
web.search_query("{query1} site:elixirforum.com OR site:hexdocs.pm OR site:github.com")
web.search_query("{query2} site:hexdocs.pm OR site:elixirforum.com")
```

Deduplicate URLs across results. Discard clearly irrelevant hits.

### 3. Spawn Parallel Research Workers

Group URLs by topic cluster. Spawn **1-3 web-researcher agents
in parallel** (one per topic cluster):

For each topic cluster, delegate one focused web research agent with explicit URLs,
required extraction fields (examples, patterns, gotchas, version compatibility), and
a concise summary target (500-800 words).
Each agent writes results to a deterministic path:
`.draught/research/{cluster-slug}/worker-{n}.md`.

Rules:

- **1 topic cluster = 1 agent** (don't mix unrelated URLs)
- **Max 5 URLs per agent** (diminishing returns beyond that)
- If only 1-3 URLs total, use single foreground agent
- **Pass URLs explicitly** — agents should NOT re-search
- Agents are haiku — cheap, fast, focused on extraction

### 4. Write Output (File-First — NEVER Dump Inline)

After ALL agents complete, synthesize summaries into ONE file.
Target: ~5KB for topic research, ~3KB for library evaluations.

Create `.draught/research/{topic-slug}.md`:

```markdown
# Research: {topic}

## Summary
{2-3 sentence answer combining all worker findings}

## Sources

### {Category}
- [{title}]({url}) - {key insight}

### Code Examples

```elixir
# From {source}: {what this demonstrates}
{code}
```

## Recommendations

1. {recommendation with evidence}
2. {recommendation with evidence}

## Watch Out For

- {gotcha from forum/issues}
- {version compatibility note}
```

### 5. After Research — STOP

**STOP and present the research summary.** Do NOT auto-transition.

Use `ask the user in chat` to let the user choose next action:

- "Plan a feature based on this research" → `/skill elixir-phoenix-plan`
- "Investigate a specific finding" → `/skill elixir-phoenix-investigate`
- "Research more on a subtopic" → continue research
- "Done" → end

**NEVER auto-invoke `/skill elixir-phoenix-plan` or any other skill after research.**
