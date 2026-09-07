defmodule Draught.Session.Journal.Retention do
  @moduledoc """
  Controls which tool-originated conversation values are retained in a journal.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:tool_arguments, :tool_output]
  defstruct [:tool_arguments, :tool_output]

  @type choice :: :omit | :retain
  @type t :: %__MODULE__{tool_arguments: choice(), tool_output: choice()}

  @doc "Builds a retention policy that omits tool arguments and output by default."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ []) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:tool_arguments, :tool_output]),
         {:ok, tool_arguments} <- choice(normalized, :tool_arguments),
         {:ok, tool_output} <- choice(normalized, :tool_output) do
      {:ok, %__MODULE__{tool_arguments: tool_arguments, tool_output: tool_output}}
    end
  end

  defp choice(attributes, key) do
    attributes
    |> Map.get(key, :omit)
    |> Value.enum([:omit, :retain], [key])
  end
end
