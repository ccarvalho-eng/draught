defmodule Draught.Web.Search.Adapter do
  @moduledoc """
  Defines the injected effect boundary for a web-search implementation.
  """

  alias Draught.Error.Normalized
  alias Draught.Web.Policy

  @type result_item :: map() | keyword() | Draught.Web.Search.Result.Item.t()
  @callback search(String.t(), Policy.t(), term()) ::
              {:ok, [result_item()]} | {:error, Normalized.t()}
end
