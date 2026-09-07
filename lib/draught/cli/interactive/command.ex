defmodule Draught.CLI.Interactive.Command do
  @moduledoc """
  Validates interactive invocation constraints and starts the shell controller.

  Startup, interaction lifecycle, and task execution remain separate modules so
  each effect boundary can be tested and replaced independently.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Controller
  alias Draught.CLI.Interactive.Startup
  alias Draught.CLI.Output
  alias Draught.CLI.UI
  alias Draught.CLI.Writer

  @doc "Starts one interactive shell and returns its stable exit status."
  @spec run(Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(%Invocation{} = invocation, %Dependencies{} = dependencies) do
    case supported(invocation, dependencies) do
      :ok -> start(invocation, dependencies)
      {:error, :prompt_required} -> write_prompt_required(invocation, dependencies)
      {:error, reason} -> write_startup_error(reason, dependencies)
    end
  end

  defp start(invocation, dependencies) do
    case Startup.prepare(invocation, dependencies) do
      {:ok, state, configuration} ->
        Controller.open(state, configuration, invocation, dependencies)

      {:error, :configuration, %Configuration.Error{} = error} ->
        error
        |> Output.configuration_error(invocation.output)
        |> Writer.emit(:stderr, :usage, dependencies)

      {:error, category, _error} ->
        category
        |> Output.task_setup_error(invocation.output)
        |> Writer.emit(:stderr, category, dependencies)
    end
  end

  defp supported(%Invocation{resume: identifier} = invocation, dependencies)
       when is_binary(identifier) do
    named_supported(invocation, dependencies)
  end

  defp supported(%Invocation{session: identifier} = invocation, dependencies)
       when is_binary(identifier) do
    named_supported(invocation, dependencies)
  end

  defp supported(%Invocation{output: :jsonl}, _dependencies) do
    {:error, :jsonl}
  end

  defp supported(%Invocation{}, dependencies) do
    terminal_supported(dependencies)
  end

  defp terminal_supported(%Dependencies{
         system: {system, system_configuration},
         terminal: {terminal, terminal_configuration}
       }) do
    terminal_result(
      system.tty?(:stdout, system_configuration),
      terminal.interactive?(terminal_configuration)
    )
  end

  defp named_supported(%Invocation{output: :jsonl}, _dependencies) do
    {:error, :prompt_required}
  end

  defp named_supported(_invocation, dependencies) do
    case terminal_supported(dependencies) do
      :ok -> :ok
      {:error, :not_a_terminal} -> {:error, :prompt_required}
    end
  end

  defp terminal_result(true, true) do
    :ok
  end

  defp terminal_result(_output_terminal?, _input_terminal?) do
    {:error, :not_a_terminal}
  end

  defp write_startup_error(reason, dependencies) do
    Writer.emit({:ok, UI.startup_error(reason)}, :stderr, :usage, dependencies)
  end

  defp write_prompt_required(invocation, dependencies) do
    invocation.output
    |> Output.task_prompt_required()
    |> Writer.emit(:stderr, :session, dependencies)
  end
end
