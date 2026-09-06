defmodule Draught.Provider.OpenAI.Transport do
  @moduledoc """
  Defines the provider-owned HTTP transport boundary.

  Implementations receive validated requests and must not retain external
  exceptions or unsuccessful response bodies in returned values.
  """

  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.OpenAI.Transport.Request
  alias Draught.Provider.OpenAI.Transport.Response

  @type config :: term()
  @type stream_action(state) :: {:cont | :halt, state, boolean()}
  @type stream_reducer(state) :: (binary(), state -> stream_action(state))

  @doc "Executes one bounded complete HTTP request."
  @callback complete(Request.t(), config()) :: {:ok, Response.t()} | {:error, Failure.t()}

  @doc "Executes one streamed HTTP request while preserving reducer state on success."
  @callback stream(Request.t(), config(), state, stream_reducer(state)) ::
              {:ok, Response.t(), state} | {:error, Failure.t(), boolean()}
            when state: term()
end
