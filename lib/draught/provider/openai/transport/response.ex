defmodule Draught.Provider.OpenAI.Transport.Response do
  @moduledoc """
  A sanitized HTTP response returned by the OpenAI transport boundary.
  """

  @enforce_keys [:status]
  defstruct [:status, :body]

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          body: binary() | nil
        }
end
