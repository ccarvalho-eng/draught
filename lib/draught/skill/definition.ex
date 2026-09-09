defmodule Draught.Skill.Definition do
  @moduledoc """
  Represents one validated instruction-only skill selected for a turn.
  """

  alias Draught.Skill.Frontmatter
  alias Draught.Skill.Metadata

  @enforce_keys [:description, :instructions, :name, :origin]
  defstruct [:description, :instructions, :name, :origin]

  @type t :: %__MODULE__{
          description: String.t(),
          instructions: String.t(),
          name: String.t(),
          origin: Metadata.origin()
        }

  @doc "Parses a complete `SKILL.md` document after a bounded filesystem read."
  @spec parse(binary(), String.t(), Metadata.origin()) :: {:ok, t()} | {:error, atom()}
  def parse(content, directory_name, origin) when is_binary(content) do
    with {:ok, metadata} <- Metadata.parse(content, directory_name, origin),
         {:ok, _fields, body} <- Frontmatter.parse(content),
         {:ok, instructions} <- instructions(body) do
      {:ok,
       %__MODULE__{
         description: metadata.description,
         instructions: instructions,
         name: metadata.name,
         origin: metadata.origin
       }}
    end
  end

  def parse(_content, _directory_name, _origin) do
    {:error, :invalid_skill}
  end

  defp instructions(body) do
    trimmed = String.trim(body)
    valid = String.valid?(trimmed) and trimmed != "" and not String.contains?(trimmed, <<0>>)
    instructions_result(valid, trimmed)
  end

  defp instructions_result(true, instructions) do
    {:ok, instructions}
  end

  defp instructions_result(false, _instructions) do
    {:error, :empty_instructions}
  end
end
