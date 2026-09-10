defmodule Draught.CLI.UI.SkillDescription do
  @moduledoc """
  Sanitizes skill metadata and produces complete summaries for compact catalogs.
  """

  alias Draught.CLI.UI.SafeLine
  alias Draught.Skill.Name

  @fallback "See skill instructions"
  @maximum_bytes 44
  @summary_boundary ~r/(?:[,;:]|\s+(?:across|as|before|by|for|from|only|so|using|when|with)\s+)/u

  @builtin_summaries %{
    "assigns-audit" => "Keep the heap pleasantly bored",
    "audit" => "The bugs won't find themselves",
    "boundaries" => "Keep contexts on speaking terms",
    "brainstorm" => "Ideas first, migrations later",
    "brief" => "Context for humans, too",
    "call-tracing" => "Follow the call; mind the mailbox",
    "challenge" => "Friendly fire for fragile plans",
    "compound" => "Bottle today's fix for tomorrow",
    "compound-docs" => "Consult yesterday's hard-won wisdom",
    "deploy" => "Production awaits; bring a rollback",
    "document" => "Future you sends its regards",
    "ecto-constraint-debug" => "Ask the database what it meant",
    "ecto-patterns" => "Changesets before regrets",
    "elixir-idioms" => "Let the BEAM carry the heavy bits",
    "examples" => "Show, don't merely moduledoc",
    "full" => "The whole ritual, bells included",
    "help" => "A compass for the skill cabinet",
    "hex-publish" => "Package, tag, release, breathe",
    "hexdocs-fetcher" => "Read the docs before inventing APIs",
    "incident-response" => "Keep calm; inspect the supervision tree",
    "init" => "Wire the rules before bending them",
    "intent-detection" => "Figure out what you meant",
    "intro" => "A guided tour, umbrella optional",
    "investigate" => "Follow the crash, question assumptions",
    "learn-from-fix" => "Make the same bug pay rent",
    "liveview-debug" => "When the socket has opinions",
    "liveview-patterns" => "Keep the socket pleasantly boring",
    "migrations" => "Schema changes without archaeology",
    "n1-check" => "One query good, one hundred suspicious",
    "oban" => "Reliable jobs for unreliable Tuesdays",
    "observability" => "If it moves, measure it",
    "perf" => "Find where milliseconds are hiding",
    "permissions" => "Least privilege, fewer surprises",
    "phoenix-contexts" => "Boundaries that survive feature requests",
    "plan" => "Measure twice, migrate once",
    "pr-review" => "Comments enter, regressions leave",
    "quick" => "Small change, full responsibility",
    "research" => "Primary sources before confident guesses",
    "review" => "Second thoughts, professionally applied",
    "runtime-durability-review" => "Assume the process dies mid-sentence",
    "security" => "Trust boundaries with sharper teeth",
    "techdebt" => "Name the mess before moving it",
    "testing" => "Make green mean something",
    "tidewave-integration" => "Ask the running system directly",
    "triage" => "Separate blockers from decorative panic",
    "upgrade" => "Move versions, not goalposts",
    "verify" => "Compile, test, then believe",
    "work" => "Turn the plan into passing tests"
  }

  @doc "Returns display-safe skill metadata with a generous defensive bound."
  @spec safe(String.t()) :: String.t()
  def safe(value) do
    SafeLine.text(value, 2_048)
  end

  @doc "Returns a short skill summary without partial words or ellipses."
  @spec summary(String.t()) :: String.t()
  def summary(description) do
    description
    |> safe()
    |> first_clause()
    |> fit_words()
  end

  @doc "Returns the display-safe public name for a catalog entry."
  @spec display_name(map()) :: String.t()
  def display_name(%{name: name, origin: origin}) do
    name
    |> Name.display(origin)
    |> safe()
  end

  @doc "Returns compact catalog copy while preserving custom skill descriptions."
  @spec catalog_summary(map()) :: String.t()
  def catalog_summary(%{description: description, name: name, origin: :builtin}) do
    case String.replace_prefix(name, "elixir-phoenix-", "") do
      ^name -> summary(description)
      suffix -> Map.get(@builtin_summaries, suffix, summary(description))
    end
  end

  def catalog_summary(%{description: description}) do
    summary(description)
  end

  defp first_clause(description) do
    description
    |> then(&Regex.split(@summary_boundary, &1, parts: 2))
    |> List.first()
    |> String.trim()
    |> String.trim_trailing(".")
  end

  defp fit_words(description) when byte_size(description) <= @maximum_bytes do
    fallback_if_empty(description)
  end

  defp fit_words(description) do
    description
    |> String.split()
    |> Enum.reduce_while("", &append_word/2)
    |> fallback_if_empty()
  end

  defp append_word(word, "") when byte_size(word) <= @maximum_bytes do
    {:cont, word}
  end

  defp append_word(word, summary) do
    candidate = summary <> " " <> word
    append_candidate(candidate, summary)
  end

  defp append_candidate(candidate, _summary) when byte_size(candidate) <= @maximum_bytes do
    {:cont, candidate}
  end

  defp append_candidate(_candidate, summary) do
    {:halt, summary}
  end

  defp fallback_if_empty("") do
    @fallback
  end

  defp fallback_if_empty(summary) do
    summary
  end
end
