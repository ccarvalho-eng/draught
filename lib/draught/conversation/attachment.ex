defmodule Draught.Conversation.Attachment do
  @moduledoc """
  A portable attachment descriptor with optional retained bytes.

  The constructor derives size and digest metadata when content is present.
  Descriptor-only values require both fields explicitly. Names are restricted
  to portable leaf names so the same value can be used safely by bundle codecs.
  """

  alias Draught.Conversation.Attachment.Builder
  alias Draught.Validation.Error

  @maximum_bytes 16_777_216

  @enforce_keys [:name, :media_type, :byte_size, :sha256]
  defstruct [:name, :media_type, :byte_size, :sha256, :content]

  @type t :: %__MODULE__{
          name: String.t(),
          media_type: String.t(),
          byte_size: non_neg_integer(),
          sha256: String.t(),
          content: binary() | nil
        }

  @doc "Builds and validates a portable attachment."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, fields} <- Builder.build(attributes, @maximum_bytes) do
      {:ok, struct!(__MODULE__, fields)}
    end
  end

  @doc "Returns the maximum supported uncompressed attachment size in bytes."
  @spec max_bytes() :: pos_integer()
  def max_bytes do
    @maximum_bytes
  end
end
