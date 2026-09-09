defmodule Draught.CLI.Interactive.Command.Dispatch do
  @moduledoc """
  Routes stateful interactive commands to their feature contexts.

  The shell controller receives tagged results and remains independent of each
  command context's implementation modules.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Inspection
  alias Draught.CLI.Interactive.Model
  alias Draught.CLI.Interactive.Session
  alias Draught.CLI.Interactive.Skill
  alias Draught.CLI.Interactive.State

  @inspection_commands [:permissions, :tools]
  @session_commands [:archive, :new, :rename, :restore, :resume, :sessions]
  @skill_commands [:skill, :skills]

  @type kind :: :inspection | :model | :session | :skill
  @type result :: {kind(), term()}

  @doc "Reports whether a command is owned by one stateful feature context."
  @spec supported?(atom()) :: boolean()
  def supported?(:model) do
    true
  end

  def supported?(command) when command in @inspection_commands do
    true
  end

  def supported?(command) when command in @session_commands do
    true
  end

  def supported?(command) when command in @skill_commands do
    true
  end

  def supported?(_command) do
    false
  end

  @doc "Runs one supported command and tags its feature-specific result."
  @spec run(
          atom(),
          String.t() | nil,
          State.t(),
          Configuration.t(),
          Invocation.t(),
          Dependencies.t()
        ) :: result()
  def run(:model, argument, state, configuration, _invocation, dependencies) do
    {:model, Model.Command.run(argument, state, configuration, dependencies)}
  end

  def run(command, _argument, state, configuration, _invocation, dependencies)
      when command in @inspection_commands do
    {:inspection, Inspection.Command.run(command, state, configuration, dependencies)}
  end

  def run(command, argument, state, configuration, invocation, dependencies)
      when command in @session_commands do
    result =
      Session.Command.run(command, argument, state, configuration, invocation, dependencies)

    {:session, result}
  end

  def run(command, argument, state, _configuration, _invocation, dependencies)
      when command in @skill_commands do
    {:skill, Skill.Command.run(command, argument, state, dependencies)}
  end
end
