defmodule Draught.CLI.Interactive.Controller do
  @moduledoc """
  Interprets interactive input while retaining shell state and terminal cleanup.

  Known slash commands never enter task prompts. Terminal restoration runs after
  every opened shell, including input failures and ordinary exits.
  """

  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Model
  alias Draught.CLI.Interactive.Session
  alias Draught.CLI.Interactive.Session.Doctor
  alias Draught.CLI.Interactive.Session.Terminal
  alias Draught.CLI.Interactive.Skill.Command
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Interactive.Turn

  @internal_status ExitStatus.value(:internal)
  @session_commands [:archive, :new, :rename, :restore, :resume, :sessions]
  @skill_commands [:skill, :skills]
  @success_status ExitStatus.value(:success)

  @doc "Opens the prompt loop and restores its terminal boundary before returning."
  @spec open(State.t(), map(), Invocation.t(), Dependencies.t()) ::
          non_neg_integer()
  def open(state, configuration, invocation, dependencies) do
    case Terminal.banner(state, invocation, dependencies) do
      0 -> loop(state, configuration, invocation, dependencies)
      status -> status
    end
  after
    Terminal.restore(dependencies)
  end

  defp loop(state, configuration, invocation, dependencies) do
    case Terminal.read(state, dependencies, invocation.color) do
      {:ok, parsed} -> handle(parsed, state, configuration, invocation, dependencies)
      :eof -> close(state, :success, dependencies)
      :interrupted -> close(state, :interrupted, dependencies)
      {:error, :write, status} -> status
      {:error, :io} -> terminal_error(dependencies)
    end
  end

  defp handle({:ok, :empty}, state, configuration, invocation, dependencies) do
    loop(state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :exit, nil}}, state, _configuration, _invocation, dependencies) do
    close(state, :success, dependencies)
  end

  defp handle({:ok, {:command, :help, nil}}, state, configuration, invocation, dependencies) do
    continue(:help, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :clear, nil}}, state, configuration, invocation, dependencies) do
    continue(:clear, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :palette, nil}}, state, configuration, invocation, dependencies) do
    continue(:help, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :status, nil}}, state, configuration, invocation, dependencies) do
    continue({:status, state}, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:command, :doctor, nil}}, state, configuration, invocation, dependencies) do
    doctor_invocation = %{
      invocation
      | command: :doctor,
        model: state.model,
        prompt: nil,
        resume: nil,
        session: nil
    }

    status = Doctor.run(doctor_invocation, dependencies)
    continue_after(status, state, configuration, invocation, dependencies)
  end

  defp handle({:ok, {:prompt, prompt}}, state, configuration, invocation, dependencies) do
    run_turn(prompt, state, configuration, invocation, dependencies)
  end

  defp handle(
         {:ok, {:command, :model, argument}},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    argument
    |> Model.Command.run(state, configuration, dependencies)
    |> handle_model_result(state, configuration, invocation, dependencies)
  end

  defp handle(
         {:ok, {:command, command, argument}},
         state,
         configuration,
         invocation,
         dependencies
       )
       when command in @session_commands do
    command
    |> Session.Command.run(argument, state, configuration, invocation, dependencies)
    |> handle_session_result(state, configuration, invocation, dependencies)
  end

  defp handle(
         {:ok, {:command, command, argument}},
         state,
         configuration,
         invocation,
         dependencies
       )
       when command in @skill_commands do
    command
    |> Command.run(argument, state, dependencies)
    |> handle_skill_result(state, configuration, invocation, dependencies)
  end

  defp handle(
         {:ok, {:command, command, _argument}},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:unavailable_command, command},
      state,
      configuration,
      invocation,
      dependencies
    )
  end

  defp handle({:ok, {kind, _value}}, state, configuration, invocation, dependencies)
       when kind in [:file, :shell] do
    continue({:unavailable_command, kind}, state, configuration, invocation, dependencies)
  end

  defp handle({:error, reason}, state, configuration, invocation, dependencies) do
    continue(
      {:input_error, reason},
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
        continue_after(status, next_state, configuration, invocation, dependencies)

      {:error, :model_required} ->
        continue(
          {:model_error, :model_required},
          state,
          configuration,
          invocation,
          dependencies,
          :stderr
        )

      {:error, _reason} ->
        continue(
          :terminal_error,
          state,
          configuration,
          invocation,
          dependencies,
          :stderr
        )
    end
  end

  defp handle_model_result(
         {:ok, next_state, next_configuration, view},
         _state,
         _configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:model_view, view},
      next_state,
      next_configuration,
      invocation,
      dependencies
    )
  end

  defp handle_model_result(
         {:error, reason},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:model_error, reason},
      state,
      configuration,
      invocation,
      dependencies,
      :stderr
    )
  end

  defp handle_session_result(
         {:ok, next_state, next_configuration, view},
         _state,
         _configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:session_view, view, next_state},
      next_state,
      next_configuration,
      invocation,
      dependencies
    )
  end

  defp handle_session_result(
         {:error, reason},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:session_error, reason},
      state,
      configuration,
      invocation,
      dependencies,
      :stderr
    )
  end

  defp handle_session_result(
         {:error, :provider, reason},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:model_error, reason},
      state,
      configuration,
      invocation,
      dependencies,
      :stderr
    )
  end

  defp handle_session_result(
         {:error, _category, reason},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    handle_session_result(
      {:error, reason},
      state,
      configuration,
      invocation,
      dependencies
    )
  end

  defp handle_skill_result(
         {:ok, {:catalog, catalog}},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue({:skills, catalog}, state, configuration, invocation, dependencies)
  end

  defp handle_skill_result(
         {:ok, {:invoke, name, prompt}},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    case Terminal.emit({:skill_selected, name}, :stdout, :success, dependencies) do
      0 -> run_turn(prompt, state, configuration, invocation, dependencies)
      status -> status
    end
  end

  defp handle_skill_result(
         {:error, reason},
         state,
         configuration,
         invocation,
         dependencies
       ) do
    continue(
      {:skill_error, reason},
      state,
      configuration,
      invocation,
      dependencies,
      :stderr
    )
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
    case Terminal.emit(content, stream, :success, dependencies) do
      0 -> loop(state, configuration, invocation, dependencies)
      status -> status
    end
  end

  defp close(state, category, dependencies) do
    Terminal.emit({:session_closed, state.session_id}, :stdout, category, dependencies)
  end

  defp terminal_error(dependencies) do
    Terminal.emit(:terminal_error, :stderr, :internal, dependencies)
  end
end
