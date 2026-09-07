defmodule Draught.Conversation.Document.Messages.FilteredAssistant do
  @moduledoc false

  alias Draught.Conversation.Message.Assistant
  alias Draught.Validation.Attributes
  alias Draught.Validation.Value

  @doc "Recognizes the explicit external sentinel for a content-filtered assistant response."
  @spec normalize(term()) :: {:ok, Assistant.t()} | :not_filtered
  def normalize(attributes) when is_map(attributes) or is_list(attributes) do
    with {:ok, %{role: raw_role, filtered: true} = normalized} <-
           Attributes.normalize(attributes, [:role, :filtered]),
         true <- map_size(normalized) == 2,
         {:ok, :assistant} <- Value.enum(raw_role, [:assistant], [:role]) do
      {:ok, Assistant.filtered()}
    else
      _not_filtered -> :not_filtered
    end
  end

  def normalize(_attributes) do
    :not_filtered
  end
end
