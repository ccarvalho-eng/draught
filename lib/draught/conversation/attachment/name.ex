defmodule Draught.Conversation.Attachment.Name do
  @moduledoc """
  Validates attachment names for portable interchange.

  Only bounded leaf names are accepted. Paths, ambiguous trailing characters,
  and platform-reserved basenames are rejected before archive construction.
  """

  alias Draught.Conversation.Attachment.Name.Windows
  alias Draught.Conversation.Attachment.PortableValue
  alias Draught.Validation.Error

  @maximum_bytes 255
  @portable_name ~r/\A[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9_-])?\z/

  @doc "Validates a bounded portable attachment leaf name."
  @spec validate(term(), [term()]) :: Error.result(String.t())
  def validate(value, path) do
    with {:ok, name} <-
           PortableValue.validate(
             value,
             path,
             @maximum_bytes,
             @portable_name,
             "must be a portable leaf name containing only letters, digits, dots, dashes, and underscores"
           ) do
      Windows.validate(name, path)
    end
  end
end
