defmodule Draught.Provider.OpenAI.Transport.Request do
  @moduledoc """
  A validated HTTP request passed to the OpenAI transport boundary.
  """

  @enforce_keys [
    :url,
    :headers,
    :body,
    :connect_timeout_ms,
    :receive_timeout_ms,
    :request_timeout_ms,
    :max_response_bytes
  ]
  defstruct [
    :url,
    :headers,
    :body,
    :connect_timeout_ms,
    :receive_timeout_ms,
    :request_timeout_ms,
    :max_response_bytes
  ]

  @type t :: %__MODULE__{
          url: String.t(),
          headers: %{optional(String.t()) => String.t()},
          body: map(),
          connect_timeout_ms: pos_integer(),
          receive_timeout_ms: pos_integer(),
          request_timeout_ms: pos_integer(),
          max_response_bytes: pos_integer()
        }
end
