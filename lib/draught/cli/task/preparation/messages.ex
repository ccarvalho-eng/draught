defmodule Draught.CLI.Task.Preparation.Messages do
  @moduledoc """
  Constructs the initial or resumed canonical message list for CLI task execution.
  """

  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Provider.Request
  alias Draught.Validation.Error

  @doc "Builds a canonical request from a new prompt and optional replay history."
  @spec request(term(), Selection.t(), term(), term()) :: Error.result(Request.t())
  def request(prompt, %Selection{} = selection, instruction, []) do
    with {:ok, system} <- Conversation.system(instruction),
         {:ok, user} <- Conversation.user(prompt) do
      Request.new(model: selection.model, messages: [system, user])
    end
  end

  def request(prompt, %Selection{} = selection, _instruction, history) do
    with {:ok, user} <- Conversation.user(prompt) do
      Request.new(model: selection.model, messages: append(history, user))
    end
  end

  defp append(history, user) when is_list(history) do
    history
    |> Enum.reverse()
    |> then(&[user | &1])
    |> Enum.reverse()
  end

  defp append(history, _user) do
    history
  end
end
