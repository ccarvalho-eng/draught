defmodule Draught.Conversation.Interchange.Bundle do
  @moduledoc """
  Encodes and decodes bounded in-memory conversation bundles.

  A bundle contains one `conversation.lmml` text manifest and optional retained
  attachment bytes under `attachments/`. Calling `encode/2` is the explicit
  attachment-export action; no filesystem paths are read by this API.

  Decoding validates the end-of-central-directory record and every archive
  entry before selective in-memory extraction. Imported values remain
  conversation data and do not grant execution authority.
  """

  alias Draught.Conversation.Interchange.Bundle.Decoder
  alias Draught.Conversation.Interchange.Bundle.Encoder
  alias Draught.Validation.Error

  @maximum_archive_bytes 104_857_600

  @doc "Encodes a canonical conversation document into deterministic bundle bytes."
  @spec encode(term(), keyword()) :: Error.result(binary())
  def encode(document, options \\ []) do
    Encoder.encode(document, options, @maximum_archive_bytes)
  end

  @doc "Decodes a validated bundle without writing archive entries to the filesystem."
  @spec decode(term()) :: Error.result(Draught.Conversation.Document.t())
  def decode(archive) do
    Decoder.decode(archive, @maximum_archive_bytes)
  end

  @doc "Returns the inclusive bundle-input limit in bytes."
  @spec max_input_bytes() :: pos_integer()
  def max_input_bytes do
    @maximum_archive_bytes
  end
end
