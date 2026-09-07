defmodule Draught.Web.Network.Resolver do
  @moduledoc """
  Defines the explicitly injected hostname-resolution boundary.
  """

  @callback resolve(String.t(), term()) :: {:ok, [:inet.ip_address()]} | {:error, term()}
end
