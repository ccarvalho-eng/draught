defmodule Draught.Skill.Repository.Builtin do
  @moduledoc """
  Provides the packaged skill catalog from immutable BEAM data.

  Skill documents and their direct references are validated and embedded while
  the application is compiled. Runtime discovery therefore does not depend on
  a release, escript, or native executable exposing its private files through
  an operating-system path.
  """

  @behaviour Draught.Skill.Repository.Adapter

  alias Draught.Skill.Catalog
  alias Draught.Skill.Definition
  alias Draught.Skill.Metadata
  alias Draught.Skill.Name
  alias Draught.Skill.Repository.Builtin.Documents

  @doc "Returns metadata for every validated packaged skill."
  @impl Draught.Skill.Repository.Adapter
  def list(workspace, environment, _configuration)
      when is_binary(workspace) and is_map(environment) do
    {entries, rejected} = Enum.reduce(Documents.all(), {[], 0}, &metadata/2)

    catalog =
      entries
      |> Enum.reverse()
      |> Catalog.new(rejected)

    {:ok, catalog}
  end

  def list(_workspace, _environment, _configuration) do
    {:error, :invalid_context}
  end

  @doc "Loads one validated packaged skill by its canonical name."
  @impl Draught.Skill.Repository.Adapter
  def fetch(name, workspace, environment, _configuration)
      when is_binary(workspace) and is_map(environment) do
    with {:ok, validated_name} <- Name.validate(name),
         {:ok, content} <- document(validated_name) do
      Definition.parse(content, validated_name, :builtin)
    end
  end

  def fetch(_name, _workspace, _environment, _configuration) do
    {:error, :invalid_context}
  end

  defp metadata({name, content}, {entries, rejected}) do
    case Metadata.parse(content, name, :builtin) do
      {:ok, entry} -> {[entry | entries], rejected}
      {:error, _reason} -> {entries, rejected + 1}
    end
  end

  defp document(name) do
    case List.keyfind(Documents.all(), name, 0) do
      {^name, content} -> {:ok, content}
      nil -> {:error, :not_found}
    end
  end
end
