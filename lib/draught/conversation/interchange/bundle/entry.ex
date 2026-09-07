defmodule Draught.Conversation.Interchange.Bundle.Entry do
  @moduledoc """
  Describes a validated entry in a conversation bundle.

  Entries retain both the portable path used by Draught and the archive name
  required for selective in-memory extraction.
  """

  @enforce_keys [:path, :kind, :name, :size, :compressed_size, :archive_name]
  defstruct [:path, :kind, :name, :size, :compressed_size, :archive_name]

  @type kind :: :attachment | :manifest
  @type t :: %__MODULE__{
          path: String.t(),
          kind: kind(),
          name: String.t() | nil,
          size: non_neg_integer(),
          compressed_size: non_neg_integer(),
          archive_name: charlist()
        }
end
