defmodule Draught.CLI.Task.Command.Execution do
  @moduledoc """
  Executes a task from one resolved configuration and workspace snapshot.

  Configuration loading remains outside this boundary so interactive shells can
  retain the authority and display state established during startup.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Instructions
  alias Draught.CLI.Task
  alias Draught.CLI.Task.Approval.Interaction
  alias Draught.CLI.Task.Command.Result
  alias Draught.CLI.Task.Named
  alias Draught.CLI.Task.Stream

  @doc "Runs one task against an already resolved execution snapshot."
  @spec run(Invocation.t(), Configuration.t(), String.t(), Dependencies.t()) ::
          non_neg_integer()
  def run(invocation, configuration, workspace, dependencies) do
    {interactive_dependencies, approval} =
      Interaction.setup(invocation, configuration, dependencies)

    stream =
      Stream.new(invocation.output, dependencies.system,
        color: invocation.color,
        approval: approval
      )

    {result, observed} =
      task(invocation, configuration, workspace, interactive_dependencies, stream)

    Result.emit(result, observed)
  end

  defp task(
         %Invocation{session: nil, resume: nil} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       ) do
    case fresh_instruction(workspace, dependencies.system) do
      {:ok, system_prompt} ->
        Task.run_observed(
          invocation.prompt,
          configuration,
          workspace,
          dependencies.task,
          stream,
          system_prompt
        )

      {:error, error} ->
        {{:error, :execution, error}, stream}
    end
  end

  defp task(
         %Invocation{session: identifier} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       )
       when is_binary(identifier) do
    case fresh_instruction(workspace, dependencies.system) do
      {:ok, system_prompt} ->
        Named.create_observed(
          identifier,
          invocation.prompt,
          configuration,
          workspace,
          environment(dependencies.system),
          dependencies.task,
          stream,
          %{system_prompt: system_prompt, session_label: invocation.session_label}
        )

      {:error, error} ->
        {{:error, :execution, error}, stream}
    end
  end

  defp task(
         %Invocation{resume: identifier} = invocation,
         configuration,
         workspace,
         dependencies,
         stream
       )
       when is_binary(identifier) do
    Named.run_observed(
      :resume,
      identifier,
      invocation.prompt,
      configuration,
      workspace,
      environment(dependencies.system),
      dependencies.task,
      stream
    )
  end

  defp environment({system, configuration}) do
    system.environment(configuration)
  end

  defp fresh_instruction(workspace, system) do
    Instructions.load(workspace, system)
  end
end
