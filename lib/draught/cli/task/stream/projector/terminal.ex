defmodule Draught.CLI.Task.Stream.Projector.Terminal do
  @moduledoc """
  Projects one task outcome into the single safe terminal CLI event.
  """

  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.CLI.Task.Stream.Projector.Terminal.Failure
  alias Draught.CLI.Task.Stream.Projector.Terminal.Success
  alias Draught.Error.Normalized
  alias Draught.Provider.Response
  alias Draught.Validation.Error

  @type projection ::
          {:emit, State.t(), Draught.CLI.Task.Stream.Event.t()}
          | {:error, :inconsistent_stream | :invalid_event}

  @doc "Projects one terminal task result and closes the projector state."
  @spec project(State.t(), Draught.CLI.Task.result()) :: projection()
  def project(%State{status: :open} = state, {:ok, %Response{} = response}) do
    Success.project(state, response)
  end

  def project(
        %State{status: :open} = state,
        {:error, category, %Normalized{} = error}
      ) do
    Failure.project(state, category, error)
  end

  def project(%State{status: :open} = state, {:error, category, %Error{} = error}) do
    Failure.project(state, category, error)
  end

  def project(%State{}, _result) do
    {:error, :invalid_event}
  end
end
