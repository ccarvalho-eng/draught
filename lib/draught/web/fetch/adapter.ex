defmodule Draught.Web.Fetch.Adapter do
  @moduledoc """
  Defines the injected effect boundary for guarded page retrieval.
  """

  alias Draught.Error.Normalized
  alias Draught.Web.Fetch.Response
  alias Draught.Web.Policy

  @callback fetch(String.t(), Policy.t(), term()) ::
              {:ok, Response.t() | map() | keyword()} | {:error, Normalized.t()}
end
