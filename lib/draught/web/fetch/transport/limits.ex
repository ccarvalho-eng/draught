defmodule Draught.Web.Fetch.Transport.Limits do
  @moduledoc false

  @enforce_keys [:max_response_bytes, :timeout_ms]
  defstruct [:max_response_bytes, :timeout_ms]

  @type t :: %__MODULE__{max_response_bytes: pos_integer(), timeout_ms: pos_integer()}
end
