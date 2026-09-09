defmodule Draught.CLI.Interactive.Skill.Invocation do
  @moduledoc """
  Separates one explicit skill reference from optional turn arguments.
  """

  @enforce_keys [:arguments, :reference]
  defstruct [:arguments, :reference]

  @type t :: %__MODULE__{arguments: String.t() | nil, reference: String.t()}

  @doc "Parses the first non-whitespace token as a skill reference."
  @spec parse(term()) :: {:ok, t()} | {:error, :invalid_name}
  def parse(value) when is_binary(value) do
    case String.split(value, ~r/\s+/, parts: 2, trim: true) do
      [reference] -> {:ok, %__MODULE__{arguments: nil, reference: reference}}
      [reference, arguments] -> {:ok, %__MODULE__{arguments: arguments, reference: reference}}
      [] -> {:error, :invalid_name}
    end
  end

  def parse(_value) do
    {:error, :invalid_name}
  end
end
