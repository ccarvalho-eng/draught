defmodule Draught.CLI.Interactive.Turn do
  @moduledoc """
  Executes one interactive prompt through the existing named-session command path.

  A completed command may establish durable session state even when its runner
  outcome failed. Durable state is detected before returning the shell to idle.
  """

  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Interactive.Turn.Persistence
  alias Draught.CLI.Task

  @doc "Runs one prompt and returns its emitted status with the next idle state."
  @spec run(String.t(), State.t(), Configuration.t(), Invocation.t(), Dependencies.t()) ::
          {:ok, non_neg_integer(), State.t()}
          | {:error, :busy | :invalid_prompt | :model_required}
  def run(prompt, state, configuration, invocation, dependencies) do
    case State.start_turn(state, prompt) do
      {:ok, running} -> execute(prompt, running, configuration, invocation, dependencies)
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute(prompt, state, configuration, invocation, dependencies) do
    task_invocation = task_invocation(invocation, state, prompt)
    resolved = %{configuration | model: state.model}
    status = Task.Command.run_resolved(task_invocation, resolved, state.workspace, dependencies)
    persisted? = persisted?(status, state, dependencies)
    {:idle, next_state} = State.finish_turn(state, persisted?)
    {:ok, status, next_state}
  end

  defp task_invocation(invocation, state, prompt) do
    selected = %{
      invocation
      | command: :task,
        model: state.model,
        prompt: prompt,
        resume: nil,
        session: nil,
        session_label: session_label(state)
    }

    session_invocation(selected, state)
  end

  defp session_invocation(invocation, %State{persisted?: true} = state) do
    %{invocation | resume: state.session_id}
  end

  defp session_invocation(invocation, %State{persisted?: false} = state) do
    %{invocation | session: state.session_id}
  end

  defp session_label(%State{
         persisted?: false,
         session_id: identifier,
         session_label: label
       })
       when label != identifier do
    label
  end

  defp session_label(%State{}) do
    nil
  end

  defp persisted?(status, state, dependencies) do
    status == ExitStatus.value(:success) or Persistence.established?(state, dependencies)
  end
end
