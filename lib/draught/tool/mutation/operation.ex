defmodule Draught.Tool.Mutation.Operation do
  @moduledoc """
  Defines serialized mutation work executed by the mutation queue.
  """

  @type result :: {:ok, String.t()} | {:error, Draught.Error.Normalized.t()}

  @doc "Runs one approved mutation value."
  @callback run(term()) :: result()
end
