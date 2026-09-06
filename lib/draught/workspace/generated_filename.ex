defmodule Draught.Workspace.GeneratedFilename do
  @moduledoc """
  Validates generated filenames before joining them to managed directories.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.PortableSegment

  @doc "Builds a generated filename without separators or traversal syntax."
  @spec new(term()) :: Error.result(String.t())
  def new(value) do
    PortableSegment.validate(value, [:filename])
  end
end
