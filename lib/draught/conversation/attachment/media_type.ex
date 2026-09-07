defmodule Draught.Conversation.Attachment.MediaType do
  @moduledoc """
  Validates the portable media-type subset accepted by attachments.

  Values are lowercase, bounded, and restricted to a type and subtype without
  parameters so serialized descriptors remain stable.
  """

  alias Draught.Conversation.Attachment.PortableValue
  alias Draught.Validation.Error

  @maximum_bytes 127
  @media_type ~r/\A[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+-]*\z/

  @doc "Validates a bounded lowercase attachment media type."
  @spec validate(term(), [term()]) :: Error.result(String.t())
  def validate(value, path) do
    PortableValue.validate(
      value,
      path,
      @maximum_bytes,
      @media_type,
      "must be a lowercase media type"
    )
  end
end
