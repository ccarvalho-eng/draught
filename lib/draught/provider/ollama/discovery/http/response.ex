defmodule Draught.Provider.Ollama.Discovery.HTTP.Response do
  @moduledoc """
  Bounded response returned by Ollama discovery HTTP implementations.
  """

  @enforce_keys [:status]
  defstruct [:status, :body]

  @type t :: %__MODULE__{status: non_neg_integer(), body: binary() | nil}
end
