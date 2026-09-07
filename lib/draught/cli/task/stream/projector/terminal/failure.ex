defmodule Draught.CLI.Task.Stream.Projector.Terminal.Failure do
  @moduledoc """
  Projects bounded normalized and setup failures into safe terminal events.
  """

  alias Draught.CLI.Output.Sanitizer
  alias Draught.CLI.Task.Stream.Event
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.Error.Normalized
  alias Draught.Validation.Error

  @maximum_code_bytes 256
  @maximum_message_bytes 4_096

  @doc "Builds one bounded normalized or non-reflective setup failure event."
  @spec project(State.t(), atom(), Normalized.t()) :: {:emit, State.t(), Event.t()}
  def project(%State{} = state, category, %Normalized{} = error) do
    event =
      Event.new(:failure, state.sequence,
        category: category,
        code: Sanitizer.text(error.code, @maximum_code_bytes),
        kind: error.kind,
        message: Sanitizer.text(error.message, @maximum_message_bytes),
        prefix_newline: state.line_open,
        retryable: error.retryable
      )

    {:emit, State.terminal(state), event}
  end

  @spec project(State.t(), atom(), Error.t()) :: {:emit, State.t(), Event.t()}
  def project(%State{} = state, category, %Error{}) do
    event =
      Event.new(:failure, state.sequence,
        category: category,
        code: "invalid_setup",
        kind: :configuration,
        message: setup_message(category),
        prefix_newline: state.line_open,
        retryable: false
      )

    {:emit, State.terminal(state), event}
  end

  defp setup_message(:provider) do
    "Task provider configuration is invalid"
  end

  defp setup_message(_category) do
    "Task execution configuration is invalid"
  end
end
