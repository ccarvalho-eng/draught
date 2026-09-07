defmodule Draught.Conversation.Interchange.Bundle.Entry do
  @moduledoc false

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
