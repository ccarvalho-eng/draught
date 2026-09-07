defmodule Draught.Conversation.Interchange.Bundle.Decoder.Header do
  @moduledoc false

  @enforce_keys [
    :made_by,
    :flags,
    :method,
    :crc,
    :compressed_size,
    :size,
    :disk,
    :external_attributes,
    :local_offset
  ]
  defstruct [
    :made_by,
    :flags,
    :method,
    :crc,
    :compressed_size,
    :size,
    :disk,
    :external_attributes,
    :local_offset,
    :name
  ]

  @type t :: %__MODULE__{
          made_by: non_neg_integer(),
          flags: non_neg_integer(),
          method: non_neg_integer(),
          crc: non_neg_integer(),
          compressed_size: non_neg_integer(),
          size: non_neg_integer(),
          disk: non_neg_integer(),
          external_attributes: non_neg_integer(),
          local_offset: non_neg_integer(),
          name: binary() | nil
        }
end
