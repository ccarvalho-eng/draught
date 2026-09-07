defmodule Draught.Web.Fetch.Transport.Limits do
  @moduledoc """
  Carries immutable byte and timeout limits into a web connection adapter.

  Values originate from validated policy and apply to one address-pinned request.
  """

  @enforce_keys [:max_response_bytes, :timeout_ms]
  defstruct [:max_response_bytes, :timeout_ms]

  @type t :: %__MODULE__{max_response_bytes: pos_integer(), timeout_ms: pos_integer()}
end
