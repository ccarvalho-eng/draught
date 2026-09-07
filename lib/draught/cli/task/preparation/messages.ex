defmodule Draught.CLI.Task.Preparation.Messages do
  @moduledoc false

  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Provider.Request
  alias Draught.Validation.Error

  @doc "Builds the canonical initial system and user message request."
  @spec request(term(), Selection.t(), term()) :: Error.result(Request.t())
  def request(prompt, %Selection{} = selection, instruction) do
    with {:ok, system} <- Conversation.system(instruction),
         {:ok, user} <- Conversation.user(prompt) do
      Request.new(model: selection.model, messages: [system, user])
    end
  end
end
