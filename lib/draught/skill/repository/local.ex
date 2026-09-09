defmodule Draught.Skill.Repository.Local do
  @moduledoc """
  Discovers local directory-based `SKILL.md` instructions with bounded reads.

  Roots and entries are scanned only one level deep. Invalid entries are
  excluded, and the first valid skill name in root precedence order wins.
  """

  @behaviour Draught.Skill.Repository.Adapter

  alias Draught.Skill.Catalog
  alias Draught.Skill.Definition
  alias Draught.Skill.Metadata
  alias Draught.Skill.Name
  alias Draught.Skill.Repository.Local.File
  alias Draught.Skill.Repository.Local.Roots

  @maximum_bytes 32_768
  @maximum_entries 256
  @maximum_frontmatter_bytes 4_096

  @doc "Returns the maximum accepted size of one complete skill document."
  @spec maximum_bytes() :: pos_integer()
  def maximum_bytes do
    @maximum_bytes
  end

  @impl Draught.Skill.Repository.Adapter
  def list(workspace, environment, _configuration)
      when is_binary(workspace) and is_map(environment) do
    {entries, rejected} =
      workspace
      |> Roots.list(environment)
      |> Enum.reduce({[], 0}, &scan_root/2)

    catalog =
      entries
      |> Enum.reverse()
      |> Catalog.new(rejected)

    {:ok, catalog}
  end

  def list(_workspace, _environment, _configuration) do
    {:error, :invalid_context}
  end

  @impl Draught.Skill.Repository.Adapter
  def fetch(name, workspace, environment, _configuration)
      when is_binary(workspace) and is_map(environment) do
    with {:ok, validated_name} <- Name.validate(name) do
      workspace
      |> Roots.list(environment)
      |> Enum.find_value(&load(&1, validated_name))
      |> fetch_result()
    end
  end

  def fetch(_name, _workspace, _environment, _configuration) do
    {:error, :invalid_context}
  end

  defp scan_root(root, {entries, rejected}) do
    case File.entries(root.path, @maximum_entries) do
      {:ok, names} -> scan_entries(names, root, entries, rejected)
      {:error, _reason} -> {entries, rejected + 1}
    end
  end

  defp scan_entries(names, root, entries, rejected) do
    Enum.reduce(names, {entries, rejected}, fn name, {found, invalid_count} ->
      case metadata(root, name) do
        {:ok, entry} -> {append_unique(found, entry), invalid_count}
        {:error, _reason} -> {found, invalid_count + 1}
      end
    end)
  end

  defp metadata(root, name) do
    directory = Path.join(root.path, name)
    skill_file = Path.join(directory, "SKILL.md")

    with {:ok, validated_name} <- Name.validate(name),
         true <- File.directory?(directory),
         {:ok, prefix} <-
           File.prefix(skill_file, @maximum_bytes, @maximum_frontmatter_bytes),
         {:ok, metadata} <- Metadata.parse(prefix, validated_name, root.origin) do
      {:ok, metadata}
    else
      _failure -> {:error, :invalid_skill}
    end
  end

  defp append_unique(entries, entry) do
    duplicate? = Enum.any?(entries, &(&1.name == entry.name))
    append_result(duplicate?, entries, entry)
  end

  defp append_result(true, entries, _entry) do
    entries
  end

  defp append_result(false, entries, entry) do
    [entry | entries]
  end

  defp load(root, name) do
    directory = Path.join(root.path, name)
    skill_file = Path.join(directory, "SKILL.md")

    with true <- File.directory?(root.path),
         true <- File.directory?(directory),
         {:ok, content} <- File.complete(skill_file, @maximum_bytes),
         {:ok, definition} <- Definition.parse(content, name, root.origin) do
      definition
    else
      _failure -> nil
    end
  end

  defp fetch_result(nil) do
    {:error, :not_found}
  end

  defp fetch_result(%Definition{} = definition) do
    {:ok, definition}
  end
end
