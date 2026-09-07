defmodule Draught.Web.Fetch.Transport.Connection do
  @moduledoc """
  Defines the address-pinned connection contract used by guarded web fetches.

  Implementations receive both the logical target and an already validated IP
  address, plus fixed response and timeout limits.
  """

  alias Draught.Web.Fetch.Transport.Limits
  alias Draught.Web.Fetch.Transport.RawResponse
  alias Draught.Web.Target

  @callback request(Target.t(), :inet.ip_address(), Limits.t(), term()) ::
              {:ok, RawResponse.t() | map()} | {:error, term()}
end
