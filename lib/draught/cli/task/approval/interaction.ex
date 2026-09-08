defmodule Draught.CLI.Task.Approval.Interaction do
  @moduledoc """
  Installs terminal approvals only for text tasks with interactive input and output.

  Explicit approval adapters and deny/allow risk modes retain precedence. Piped
  tasks, JSON Lines output, and library task APIs do not acquire terminal input.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Task.Approval.Interactive
  alias Draught.CLI.Task.Approval.Prompt

  @doc "Returns invocation-local dependencies and an optional terminal approval channel."
  @spec setup(Invocation.t(), Configuration.t(), Dependencies.t()) ::
          {Dependencies.t(), Prompt.t() | nil}
  def setup(%Invocation{output: :text}, %Configuration{risk: :ask}, dependencies) do
    available = dependencies.task.approval == nil and available?(dependencies)
    install(available, dependencies)
  end

  def setup(_invocation, _configuration, dependencies) do
    {dependencies, nil}
  end

  defp available?(dependencies) do
    {terminal, configuration} = dependencies.terminal
    {system, system_configuration} = dependencies.system

    function_exported?(terminal, :request_line, 1) and
      function_exported?(terminal, :cancel_read, 2) and
      terminal.interactive?(configuration) and
      system.tty?(:stdout, system_configuration) and
      system.tty?(:stderr, system_configuration)
  end

  defp install(true, dependencies) do
    scope = make_ref()
    policy = {Interactive, %{owner: self(), scope: scope, timeout_ms: 25_000}}
    task = %{dependencies.task | approval: policy}
    {%{dependencies | task: task}, Prompt.new(scope, dependencies.terminal)}
  end

  defp install(false, dependencies) do
    {dependencies, nil}
  end
end
