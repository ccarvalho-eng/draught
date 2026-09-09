defmodule Draught.CLI.Interactive.Command.Catalog do
  @moduledoc """
  Provides the canonical metadata for interactive slash commands.

  Parsing, help rendering, and terminal completion consume this catalog so a
  command cannot silently diverge between those interfaces.
  """

  alias Draught.CLI.Interactive.Command.Catalog.Entry

  @active [
    %Entry{
      name: :help,
      usage: "/help",
      argument: :none,
      availability: :active,
      description: "Show commands and input forms"
    },
    %Entry{
      name: :clear,
      usage: "/clear",
      argument: :none,
      availability: :active,
      description: "Clear the terminal"
    },
    %Entry{
      name: :status,
      usage: "/status",
      argument: :none,
      availability: :active,
      description: "Show the active session configuration"
    },
    %Entry{
      name: :permissions,
      usage: "/permissions",
      argument: :none,
      availability: :active,
      description: "Show workspace and tool authority"
    },
    %Entry{
      name: :doctor,
      usage: "/doctor",
      argument: :none,
      availability: :active,
      description: "Run diagnostics"
    },
    %Entry{
      name: :sessions,
      usage: "/sessions",
      argument: :none,
      availability: :active,
      description: "List sessions in this workspace"
    },
    %Entry{
      name: :resume,
      usage: "/resume [REF]",
      argument: :optional,
      availability: :active,
      description: "Select an active session by number, ID, or name"
    },
    %Entry{
      name: :new,
      usage: "/new [ID]",
      argument: :optional,
      availability: :active,
      description: "Start a fresh session"
    },
    %Entry{
      name: :rename,
      usage: "/rename NAME",
      argument: :required,
      availability: :active,
      description: "Change the session display name"
    },
    %Entry{
      name: :archive,
      usage: "/archive [ID]",
      argument: :optional,
      availability: :active,
      description: "Archive a session"
    },
    %Entry{
      name: :restore,
      usage: "/restore [ID]",
      argument: :optional,
      availability: :active,
      description: "Restore an archived session"
    },
    %Entry{
      name: :model,
      usage: "/model [REF]",
      argument: :optional,
      availability: :active,
      description: "List or select a model by number or exact name"
    },
    %Entry{
      name: :tools,
      usage: "/tools",
      argument: :none,
      availability: :active,
      description: "Show available tools and risk classes"
    },
    %Entry{
      name: :skills,
      usage: "/skills",
      argument: :none,
      availability: :active,
      description: "Show skill catalogs"
    },
    %Entry{
      name: :"custom-skills",
      usage: "/custom-skills",
      argument: :none,
      availability: :active,
      description: "List workspace and user skills"
    },
    %Entry{
      name: :"builtin-skills",
      usage: "/builtin-skills",
      argument: :none,
      availability: :active,
      description: "List packaged skills"
    },
    %Entry{
      name: :skill,
      usage: "/skill REF",
      argument: :required,
      availability: :active,
      description: "Apply a skill by number or exact name"
    },
    %Entry{
      name: :exit,
      usage: "/exit",
      argument: :none,
      availability: :active,
      description: "Close the interactive session"
    }
  ]

  @reserved [
    %Entry{
      name: :provider,
      usage: "/provider",
      argument: :optional,
      availability: :reserved,
      description: "Inspect or select a provider"
    },
    %Entry{
      name: :web,
      usage: "/web",
      argument: :none,
      availability: :reserved,
      description: "Inspect web capability state"
    },
    %Entry{
      name: :context,
      usage: "/context",
      argument: :none,
      availability: :reserved,
      description: "Show retained context sources"
    },
    %Entry{
      name: :compact,
      usage: "/compact",
      argument: :none,
      availability: :reserved,
      description: "Create a summary checkpoint"
    },
    %Entry{
      name: :diff,
      usage: "/diff",
      argument: :none,
      availability: :reserved,
      description: "Show workspace changes"
    },
    %Entry{
      name: :review,
      usage: "/review",
      argument: :none,
      availability: :reserved,
      description: "Review workspace changes"
    },
    %Entry{
      name: :details,
      usage: "/details",
      argument: :none,
      availability: :reserved,
      description: "Toggle bounded execution metadata"
    }
  ]

  @doc "Returns active commands in their stable display order."
  @spec active() :: [Entry.t()]
  def active do
    @active
  end

  @doc "Returns reserved commands in their stable display order."
  @spec reserved() :: [Entry.t()]
  def reserved do
    @reserved
  end

  @doc "Returns every known command in completion order."
  @spec all() :: [Entry.t()]
  def all do
    @active ++ @reserved
  end

  @doc "Finds a command by its external name without allocating an atom."
  @spec find(term()) :: Entry.t() | nil
  def find(name) when is_binary(name) do
    Enum.find(all(), &(Atom.to_string(&1.name) == name))
  end

  def find(_name) do
    nil
  end
end
