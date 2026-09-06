defmodule Draught.Session.Identifier do
  @moduledoc """
  Validates session identifiers used in local storage paths.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.PortableSegment

  @doc "Builds a session identifier without separators or traversal syntax."
  @spec new(term()) :: Error.result(String.t())
  def new(value) do
    PortableSegment.validate(value, [:session_id])
  end
end
