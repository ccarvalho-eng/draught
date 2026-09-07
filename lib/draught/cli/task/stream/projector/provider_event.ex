defmodule Draught.CLI.Task.Stream.Projector.ProviderEvent do
  @moduledoc """
  Projects content-bearing runner events into the closed public CLI vocabulary.
  """

  alias Draught.CLI.Output.Sanitizer
  alias Draught.CLI.Task.Stream.Event
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Tool.Result

  @type projection ::
          {:emit, State.t(), Event.t()} | {:skip, State.t()} | {:error, :invalid_event}

  @doc "Projects one ordered provider or tool event into zero or one safe CLI events."
  @spec project(State.t(), Draught.Execution.Runner.Event.t()) :: projection()
  def project(
        %State{status: :open} = state,
        {:provider_event, _iteration, %Delta{kind: :reasoning}}
      ) do
    {:skip, state}
  end

  def project(
        %State{status: :open} = state,
        {:provider_event, iteration, %Delta{kind: :text, content: content}}
      ) do
    content
    |> Sanitizer.text()
    |> text_delta(state, iteration)
  end

  def project(
        %State{status: :open} = state,
        {:provider_event, iteration, %ToolCall{call: call}}
      ) do
    event =
      Event.new(:tool_call, state.sequence,
        iteration: iteration,
        name: Sanitizer.text(call.name),
        prefix_newline: state.line_open
      )

    {:emit, State.advance(state, false), event}
  end

  def project(%State{status: :open} = state, {:provider_result, iteration, _result}) do
    {:skip, State.retain_iteration(state, iteration)}
  end

  def project(
        %State{status: :open} = state,
        {:tool_result, iteration, %Result{} = result}
      ) do
    event =
      Event.new(:tool_result, state.sequence,
        code: error_code(result.error),
        iteration: iteration,
        name: Sanitizer.text(result.name),
        prefix_newline: state.line_open,
        status: result.status
      )

    {:emit, State.advance(state, false), event}
  end

  def project(%State{}, _event) do
    {:error, :invalid_event}
  end

  defp text_delta("", state, _iteration) do
    {:skip, state}
  end

  defp text_delta(content, state, iteration) do
    event = Event.new(:text_delta, state.sequence, content: content, iteration: iteration)
    {:emit, State.record_text(state, iteration, content), event}
  end

  defp error_code(nil) do
    nil
  end

  defp error_code(%Normalized{code: code}) do
    Sanitizer.text(code)
  end
end
