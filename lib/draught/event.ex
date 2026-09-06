defmodule Draught.Event do
  @moduledoc """
  Constructs and identifies canonical provider event variants.
  """

  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Event.Provider.ToolCall
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @types [:completed, :delta, :failed, :tool_call]

  @type nonterminal :: Delta.t() | ToolCall.t()
  @type terminal :: Completed.t() | Failed.t()
  @type t :: nonterminal() | terminal()

  @doc "Builds a typed event from external attributes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [
             :type,
             :kind,
             :content,
             :call,
             :response,
             :error
           ]),
         {:ok, raw_type} <- Attributes.fetch_required(normalized, :type),
         {:ok, type} <- Value.enum(raw_type, @types, [:type]) do
      type
      |> build(Map.delete(normalized, :type))
      |> prefix_type_error(type)
    end
  end

  @doc "Validates a typed event, including manually constructed structs."
  @spec validate(term()) :: Error.result(t())
  def validate(%Completed{response: response}) do
    Completed.new(response: response)
  end

  def validate(%Delta{kind: kind, content: content}) do
    Delta.new(kind: kind, content: content)
  end

  def validate(%Failed{error: error}) do
    Failed.new(error: error)
  end

  def validate(%ToolCall{call: call}) do
    ToolCall.new(call: call)
  end

  def validate(_event) do
    Error.single([], :invalid_type, "must be a canonical provider event")
  end

  @doc "Returns the stable type derived from an event variant."
  @spec type(t()) :: :completed | :delta | :failed | :tool_call
  def type(%Completed{}) do
    :completed
  end

  def type(%Delta{}) do
    :delta
  end

  def type(%Failed{}) do
    :failed
  end

  def type(%ToolCall{}) do
    :tool_call
  end

  defp build(:completed, attributes) do
    Completed.new(attributes)
  end

  defp build(:delta, attributes) do
    Delta.new(attributes)
  end

  defp build(:failed, attributes) do
    Failed.new(attributes)
  end

  defp build(:tool_call, attributes) do
    ToolCall.new(attributes)
  end

  defp prefix_type_error({:ok, _event} = result, _type) do
    result
  end

  defp prefix_type_error({:error, %Error{} = error}, type) do
    prefixed =
      Enum.map(error.violations, fn violation ->
        %{violation | path: [type | violation.path]}
      end)

    {:error, Error.new(prefixed)}
  end
end
