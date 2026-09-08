defmodule Draught.Session.Journal.Replay do
  @moduledoc """
  Canonical state reconstructed from a complete session journal.
  """

  @enforce_keys [
    :created_at,
    :id,
    :last_turn_id,
    :messages,
    :model,
    :next_sequence,
    :provider,
    :terminal,
    :updated_at,
    :usage
  ]
  defstruct [
    :created_at,
    :id,
    :last_turn_id,
    :messages,
    :model,
    :next_sequence,
    :provider,
    :terminal,
    :turn_base_messages,
    :updated_at,
    :usage
  ]

  @type terminal ::
          :empty
          | {:running, pos_integer()}
          | {:interrupted, pos_integer()}
          | {:completed, pos_integer(), Draught.Execution.Runner.result()}

  @type t :: %__MODULE__{
          created_at: DateTime.t() | nil,
          id: String.t(),
          last_turn_id: non_neg_integer(),
          messages: [Draught.Conversation.Message.t()],
          model: String.t() | nil,
          next_sequence: pos_integer(),
          provider: String.t() | nil,
          terminal: terminal(),
          turn_base_messages: [Draught.Conversation.Message.t()] | nil,
          updated_at: DateTime.t() | nil,
          usage: Draught.Provider.Usage.t() | nil
        }

  @doc "Builds an empty replay value for a validated session identifier."
  @spec empty(String.t()) :: t()
  def empty(id) do
    %__MODULE__{
      created_at: nil,
      id: id,
      last_turn_id: 0,
      messages: [],
      model: nil,
      next_sequence: 1,
      provider: nil,
      terminal: :empty,
      turn_base_messages: nil,
      updated_at: nil,
      usage: nil
    }
  end
end
