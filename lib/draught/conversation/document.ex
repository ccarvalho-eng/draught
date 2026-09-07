defmodule Draught.Conversation.Document do
  @moduledoc """
  A versioned, provider-neutral conversation interchange value.

  Documents contain only canonical conversation data, optional aggregate token
  usage, JSON-compatible metadata, and explicit attachment descriptors. They do
  not contain executable approval, provider, tool, command, credential, web, or
  workspace configuration. Metadata is retained as inert data and is never an
  authorization source.

  Session journals remain the durable source of truth. A document is a derived
  value intended for deterministic export and import. External message data
  represents a provider-filtered assistant response as
  `%{"role" => "assistant", "filtered" => true}`; this sentinel is accepted
  only by the document boundary and cannot enter provider requests through the
  general message constructor.
  """

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Document.Builder
  alias Draught.Conversation.Message
  alias Draught.Validation.Error
  alias Draught.Validation.JSON

  @schema_version 1

  @enforce_keys [:schema_version, :messages, :usage, :metadata, :attachments]
  defstruct [:schema_version, :messages, :usage, :metadata, :attachments]

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          messages: nonempty_list(Message.t()),
          usage: Draught.Provider.Usage.t() | nil,
          metadata: %{String.t() => JSON.value()},
          attachments: [Attachment.t()]
        }

  @doc "Builds and validates a conversation interchange document."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, fields} <- Builder.build(attributes, @schema_version) do
      {:ok, struct!(__MODULE__, fields)}
    end
  end

  @doc "Returns the current conversation document schema version."
  @spec schema_version() :: pos_integer()
  def schema_version do
    @schema_version
  end
end
