defmodule Draught.Skill.Metadata do
  @moduledoc """
  Holds bounded model-visible metadata for one discovered skill.

  Catalog entries intentionally omit instruction bodies and filesystem paths.
  """

  alias Draught.Skill.Frontmatter
  alias Draught.Skill.Name

  @origins [:workspace_draught, :workspace_agents, :user_draught, :user_agents]
  @maximum_description_bytes 1_024
  @control ~r/[[:cntrl:]]/u

  @enforce_keys [:description, :name, :origin]
  defstruct [:description, :name, :origin]

  @type origin :: :workspace_draught | :workspace_agents | :user_draught | :user_agents
  @type t :: %__MODULE__{
          description: String.t(),
          name: String.t(),
          origin: origin()
        }

  @doc "Parses and validates catalog metadata from a bounded file prefix."
  @spec parse(binary(), String.t(), origin()) :: {:ok, t()} | {:error, atom()}
  def parse(content, directory_name, origin)
      when is_binary(content) and origin in @origins do
    with {:ok, fields, _body} <- Frontmatter.parse(content),
         name_value = Map.get(fields, "name"),
         {:ok, name} <- Name.validate(name_value),
         :ok <- matching_name(name, directory_name),
         description_value = Map.get(fields, "description"),
         {:ok, description} <- description(description_value) do
      {:ok, %__MODULE__{description: description, name: name, origin: origin}}
    end
  end

  def parse(_content, _directory_name, _origin) do
    {:error, :invalid_metadata}
  end

  defp matching_name(name, name) do
    :ok
  end

  defp matching_name(_name, _directory_name) do
    {:error, :name_mismatch}
  end

  defp description(value) when is_binary(value) do
    valid =
      String.valid?(value) and byte_size(value) > 0 and
        byte_size(value) <= @maximum_description_bytes and String.trim(value) == value and
        not Regex.match?(@control, value)

    description_result(valid, value)
  end

  defp description(_value) do
    {:error, :invalid_description}
  end

  defp description_result(true, value) do
    {:ok, value}
  end

  defp description_result(false, _value) do
    {:error, :invalid_description}
  end
end
