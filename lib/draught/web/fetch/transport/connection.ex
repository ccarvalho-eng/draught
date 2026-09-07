defmodule Draught.Web.Fetch.Transport.Connection do
  @moduledoc false

  alias Draught.Web.Fetch.Transport.Limits
  alias Draught.Web.Fetch.Transport.RawResponse
  alias Draught.Web.Target

  @callback request(Target.t(), :inet.ip_address(), Limits.t(), term()) ::
              {:ok, RawResponse.t() | map()} | {:error, term()}
end
