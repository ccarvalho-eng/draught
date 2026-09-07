defmodule Draught.CLI.Interactive.Controller do
  @moduledoc """
  Interprets interactive input while retaining shell state and terminal cleanup.

  Known slash commands never enter task prompts. Terminal restoration runs after
  every opened shell, including input failures and ordinary exits.
  """

  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Doctor.Command
  alias Draught.CLI.Interactive.Input
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Interactive.Turn
  alias Draught.CLI.UI
  alias Draught.CLI.Writer

  @internal_status ExitStatus.value(:internal)
  @success_status ExitStatus.value(:success)

  @doc "Opens the prompt loop and restores its terminal boundary before returning."
  @spec open(State.t(), Configuration.t(), Invocation.t(), Dependencies.t()) ::
          non_neg_integer()
  def open(state, configuration, invocation, dependencies) do
    case write_banner(state, invocation, dependencies) do
      0 -> loop(state, configuration, invocation, dependencies)
      status -> status
    end
  after
    restore(dependencies.terminal)
  end

  defp loop(state, configuration, invocation, dependencies) do
    case read(dependencies) do
      {:ok, input} -> handle(Input.parse(input), state, configuration, invocation, dependencies)
      :eof -> close(state, :success, dependencies)
      :interrupted -> close(state, :interrupted, dependencies)
      {:error, :write, status} -> status
      {:error, :io} -> terminal_error(dependencies)
    end
  end

  defp read(dependencies) do
    case write(UI.prompt(), :stdout, :success, dependencies) do
      0 -> read_line(dependencies.terminal)
      status -> {:error, :write, status}
    end
  end

  defp handle({:ok, :empty}, state, configuration, invocation, dependencies) do
    loop(state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :exit, nil}}, state, _configuration, _invocation, dependencies) do
    close(state, :success, dependencies)
  end

  defp handle({:ok, {:command, :help, nil}}, state, configuration, invocation, dependencies) do
    continue(UI.help(), state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :palette, nil}}, state, configuration, invocation, dependencies) do
    continue(UI.help(), state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :status, nil}}, state, configuration, invocation, dependencies) do
    continue(UI.status(state), state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :doctor, nil}}, state, configuration, invocation, dependencies) do
    doctor_invocation = %{invocation | command: :doctor, prompt: nil, resume: nil, session: nil}
    status = Command.run(doctor_invocation, dependencies)
    continue_after(status, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:prompt, prompt}}, state, configuration, invocation, dependencies) do
    run_turn(prompt, state, configuration, invocation, dependencies)
  end

  defp handle(
         {:ok, {:command, command, _argument}},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      UI.unavailable_command(command),
      state,
      configuration,
      invocation,
      dependencies
    )
  end

  defp handle({:ok, {kind, _value}}, state, configuration, invocation, dependencies)
       when kind in [:file, :shell] do
    continue(UI.unavailable_command(kind), state, configuration, invocation, dependencies)
  end

  defp handle({:error, reason}, state, configuration, invocation, dependencies) do
    continue(
      UI.input_error(reason),
      state,
      configuration,
      invocation,
      dependencies,
      :stderr
    )
  end

  defp run_turn(prompt, state, configuration, invocation, dependencies) do
    case Turn.run(prompt, state, configuration, invocation, dependencies) do
      {:ok, @success_status, next_state} ->
        continue_after(@success_status, next_state, configuration, invocation, dependencies)

      {:ok, status, next_state} ->
        close_after_failure(status, next_state, dependencies)

      {:error, _reason} ->
        continue(
          UI.terminal_error(),
          state,
          configuration,
          invocation,
          dependencies,
          :stderr
        )
    end
  end

  defp close_after_failure(status, state, dependencies) do
    case write(UI.session_closed(state.session_id), :stdout, :success, dependencies) do
      @success_status -> status
      @internal_status -> @internal_status
    end
  end

  defp continue_after(@internal_status, _state, _configuration, _invocation, _dependencies) do
    @internal_status
  end

  defp continue_after(_status, state, configuration, invocation, dependencies) do
    loop(state, configuration, invocation, dependencies)
  end

  defp continue(
         content,
         state,
         configuration,
         invocation,
         dependencies,
         stream \\ :stdout
       ) do
    case write(content, stream, :success, dependencies) do
      0 -> loop(state, configuration, invocation, dependencies)
      status -> status
    end
  end

  defp write_banner(state, invocation, dependencies) do
    {system, configuration} = dependencies.system
    width = terminal_width(system.columns(configuration))
    styled? = styled?(invocation.color, system.tty?(:stdout, configuration))
    write(UI.banner(state, width, styled?), :stdout, :success, dependencies)
  end

  defp terminal_width({:ok, columns}) do
    columns
  end

  defp terminal_width({:error, :unavailable}) do
    50
  end

  defp styled?(:never, _terminal?) do
    false
  end

  defp styled?(_color, terminal?) do
    terminal?
  end

  defp close(state, category, dependencies) do
    write(UI.session_closed(state.session_id), :stdout, category, dependencies)
  end

  defp terminal_error(dependencies) do
    write(UI.terminal_error(), :stderr, :internal, dependencies)
  end

  defp write(content, stream, category, dependencies) do
    Writer.emit({:ok, content}, stream, category, dependencies)
  end

  defp read_line({terminal, configuration}) do
    terminal.read_line(configuration)
  end

  defp restore({terminal, configuration}) do
    terminal.restore(configuration)
  end
end
