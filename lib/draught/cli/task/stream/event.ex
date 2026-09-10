defmodule Draught.CLI.Task.Stream.Event do
  @moduledoc """
  Represents one safe logical event accepted by the CLI stream renderers.

  Raw provider, tool, and session values are reduced to this closed projection
  before they reach terminal or JSON encoding.
  """

  @types [:failure, :success, :text_delta, :tool_call, :tool_result]

  @enforce_keys [:sequence, :type]
  defstruct [
    :category,
    :code,
    :content,
    :finish_reason,
    :heading,
    :iteration,
    :kind,
    :message,
    :name,
    :prefix_newline,
    :retryable,
    :sequence,
    :status,
    :streamed,
    :target,
    :type,
    :usage
  ]

  @type type :: :failure | :success | :text_delta | :tool_call | :tool_result
  @type t :: %__MODULE__{
          category: atom() | nil,
          code: String.t() | nil,
          content: String.t() | nil,
          finish_reason: atom() | nil,
          heading: boolean() | nil,
          iteration: pos_integer() | nil,
          kind: atom() | nil,
          message: String.t() | nil,
          name: String.t() | nil,
          prefix_newline: boolean() | nil,
          retryable: boolean() | nil,
          sequence: pos_integer(),
          status: atom() | nil,
          streamed: boolean() | nil,
          target: String.t() | nil,
          type: type(),
          usage: map() | nil
        }

  @doc "Builds one internal event from trusted projected attributes."
  @spec new(type(), pos_integer(), keyword()) :: t()
  def new(type, sequence, attributes \\ [])
      when type in @types and is_integer(sequence) and sequence > 0 do
    attributes
    |> Keyword.put(:type, type)
    |> Keyword.put(:sequence, sequence)
    |> then(&struct!(__MODULE__, &1))
  end
end
