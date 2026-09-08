defmodule Draught.CLI.Interactive.Session.Terminal do
  @moduledoc """
  Owns terminal input and presentation for an interactive session.

  The controller exchanges semantic views with this boundary rather than
  depending on concrete rendering, writing, or input parsing modules.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Input
  alias Draught.CLI.Interactive.Model
  alias Draught.CLI.Interactive.Session.Command
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.UI
  alias Draught.CLI.Writer

  @type parsed_input :: {:ok, Input.action()} | {:error, Input.error()}
  @type view ::
          :help
          | :terminal_error
          | {:input_error, atom()}
          | {:model_error, term()}
          | {:model_view, Model.Command.view()}
          | {:session_closed, String.t()}
          | {:session_error, term()}
          | {:session_view, Command.view(), State.t()}
          | {:status, State.t()}
          | {:unavailable_command, atom()}

  @doc "Renders and writes the bounded session banner for the current terminal."
  @spec banner(State.t(), Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def banner(state, invocation, dependencies) do
    {system, configuration} = dependencies.system
    width = terminal_width(system.columns(configuration))
    styled? = styled?(invocation.color, system.tty?(:stdout, configuration))

    state
    |> UI.banner(width, styled?)
    |> write(:stdout, :success, dependencies)
  end

  @doc "Frames one terminal read and returns input only after both boundaries are written."
  @spec read(State.t(), Dependencies.t(), :auto | :always | :never) ::
          {:ok, parsed_input()}
          | :eof
          | :interrupted
          | {:error, :io}
          | {:error, :write, non_neg_integer()}
  def read(%State{} = state, dependencies, color \\ :never) do
    {system, configuration} = dependencies.system
    width = terminal_width(system.columns(configuration))
    styled? = styled?(color, system.tty?(:stdout, configuration))
    opening = UI.input_area(:open, state, width, styled?)

    case write(opening, :stdout, :success, dependencies) do
      0 ->
        dependencies.terminal
        |> read_line()
        |> finish_read({state, styled?}, dependencies)

      status ->
        {:error, :write, status}
    end
  end

  @doc "Renders and writes one semantic interactive-session view."
  @spec emit(view(), :stdout | :stderr, atom(), Dependencies.t()) :: non_neg_integer()
  def emit(view, stream, category, dependencies) do
    view
    |> render()
    |> write(stream, category, dependencies)
  end

  @doc "Restores the configured terminal after the interactive shell closes."
  @spec restore(Dependencies.t()) :: :ok
  def restore(%Dependencies{terminal: {terminal, configuration}}) do
    terminal.restore(configuration)
  end

  defp parse_read({:ok, input}) do
    {:ok, Input.parse(input)}
  end

  defp parse_read(result) do
    result
  end

  defp finish_read(result, {state, styled?}, dependencies) do
    {system, configuration} = dependencies.system
    width = terminal_width(system.columns(configuration))

    closing = [
      read_separator(result),
      UI.input_area(:close, state, width, styled?),
      "\n"
    ]

    case write(closing, :stdout, :success, dependencies) do
      0 -> parse_read(result)
      status -> {:error, :write, status}
    end
  end

  defp read_separator({:ok, input}) do
    input
    |> String.ends_with?("\n")
    |> line_separator()
  end

  defp read_separator(_result) do
    "\n"
  end

  defp line_separator(true) do
    ""
  end

  defp line_separator(false) do
    "\n"
  end

  defp render(:help) do
    UI.help()
  end

  defp render(:terminal_error) do
    UI.terminal_error()
  end

  defp render({:input_error, reason}) do
    UI.input_error(reason)
  end

  defp render({:model_error, reason}) do
    UI.model_error(reason)
  end

  defp render({:model_view, {:models, models, current_model}}) do
    UI.models(models, current_model)
  end

  defp render({:model_view, {:selected, model}}) do
    UI.model_selected(model)
  end

  defp render({:session_closed, identifier}) do
    UI.session_closed(identifier)
  end

  defp render({:session_error, reason}) do
    UI.session_error(reason)
  end

  defp render({:session_view, {:sessions, entries, filter}, state}) do
    UI.sessions(entries, state.session_id, filter)
  end

  defp render({:session_view, {event, value}, state})
       when event in [:archived, :renamed, :restored, :selected] do
    [UI.session_event(event, value), UI.status(state)]
  end

  defp render({:status, state}) do
    UI.status(state)
  end

  defp render({:unavailable_command, command}) do
    UI.unavailable_command(command)
  end

  defp write(content, stream, category, dependencies) do
    Writer.emit({:ok, content}, stream, category, dependencies)
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

  defp read_line({terminal, configuration}) do
    terminal.read_line(configuration)
  end
end
