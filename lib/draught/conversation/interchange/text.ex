defmodule Draught.Conversation.Interchange.Text do
  @moduledoc """
  Encodes and decodes a bounded Markdown-superset conversation artifact.

  The leading `draught.json` extension is authoritative. The Markdown that
  follows is a derived, human-readable view and is not interpreted on import.
  Non-empty Markdown without a Draught extension imports as one user message.

  Exports redact reasoning, tool arguments, tool result details, metadata, and
  attachments by default. Callers may retain selected fields explicitly through
  the `:retain` option.
  """

  alias Draught.Conversation.Interchange.Text.Decoder
  alias Draught.Conversation.Interchange.Text.Encoder
  alias Draught.Validation.Error

  @maximum_input_bytes 33_554_432

  @doc "Encodes a conversation document into deterministic text."
  @spec encode(term(), keyword()) :: Error.result(String.t())
  def encode(document, options \\ []) do
    Encoder.encode(document, options, @maximum_input_bytes)
  end

  @doc "Decodes a Draught text artifact or imports plain Markdown."
  @spec decode(term()) :: Error.result(Draught.Conversation.Document.t())
  def decode(input) do
    Decoder.decode(input, @maximum_input_bytes)
  end

  @doc "Returns the inclusive encoded-input limit in bytes."
  @spec max_input_bytes() :: pos_integer()
  def max_input_bytes do
    @maximum_input_bytes
  end
end
