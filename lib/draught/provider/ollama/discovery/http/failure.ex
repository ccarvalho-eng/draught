defmodule Draught.Provider.Ollama.Discovery.HTTP.Failure do
  @moduledoc """
  Sanitized failure returned by an Ollama discovery HTTP implementation.
  """

  @enforce_keys [:reason]
  defstruct [:reason]

  @type reason :: :timeout | :unavailable | :response_too_large | :unknown
  @type t :: %__MODULE__{reason: reason()}

  @doc "Builds a failure from the closed reason set."
  @spec new(reason()) :: t()
  def new(reason) when reason in [:timeout, :unavailable, :response_too_large, :unknown] do
    %__MODULE__{reason: reason}
  end
end
