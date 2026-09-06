defmodule Draught.Provider.OpenAI.Transport.Failure do
  @moduledoc """
  A sanitized failure from the HTTP client boundary.
  """

  @type reason ::
          :closed
          | :connection_refused
          | :response_too_large
          | :timeout
          | :unknown
          | :unprocessed

  @enforce_keys [:reason]
  defstruct [:reason]

  @type t :: %__MODULE__{reason: reason()}

  @doc "Builds a failure from a closed set of transport reasons."
  @spec new(reason()) :: t()
  def new(reason)
      when reason in [
             :closed,
             :connection_refused,
             :response_too_large,
             :timeout,
             :unknown,
             :unprocessed
           ] do
    %__MODULE__{reason: reason}
  end
end
