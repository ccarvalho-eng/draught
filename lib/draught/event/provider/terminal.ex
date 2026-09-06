defmodule Draught.Event.Provider.Terminal do
  @moduledoc """
  Identifies the result carried by terminal provider events.
  """

  alias Draught.Error.Normalized
  alias Draught.Event
  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Failed
  alias Draught.Provider.Response

  @type result ::
          {:ok, Response.t()}
          | {:error, Normalized.t()}

  @doc "Builds the terminal event for a canonical provider result."
  @spec new(result()) :: Draught.Validation.result(Completed.t() | Failed.t())
  def new({:ok, response}) do
    Completed.new(response: response)
  end

  def new({:error, error}) do
    Failed.new(error: error)
  end

  @doc "Returns the result carried by a terminal event."
  @spec result(Event.t()) :: {:ok, result()} | :not_terminal
  def result(%Completed{response: response}) do
    {:ok, {:ok, response}}
  end

  def result(%Failed{error: error}) do
    {:ok, {:error, error}}
  end

  def result(_event) do
    :not_terminal
  end
end
