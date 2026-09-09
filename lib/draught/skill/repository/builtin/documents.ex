defmodule Draught.Skill.Repository.Builtin.Documents do
  @moduledoc """
  Holds compile-time validated built-in skill documents as immutable application data.

  The source Markdown files remain external compiler resources so changes force
  recompilation without making packaged runtimes depend on filesystem paths.
  """

  alias Draught.Skill.Repository.Local.Bundle

  @maximum_entry_bytes 32_768
  @catalog_root Application.app_dir(:draught, "priv/builtin_skills/catalog")
  @resource_paths @catalog_root
                  |> Path.join("**/*.md")
                  |> Path.wildcard()
                  |> Enum.sort()

  for path <- @resource_paths do
    @external_resource path
  end

  @documents @catalog_root
             |> Path.join("*")
             |> Path.wildcard()
             |> Enum.filter(&File.dir?/1)
             |> Enum.sort()
             |> Enum.map(fn directory ->
               name = Path.basename(directory)
               {:ok, content} = Bundle.complete(directory, @maximum_entry_bytes)
               {name, content}
             end)

  @doc "Returns every validated built-in skill name and complete instruction document."
  @spec all() :: [{String.t(), String.t()}]
  def all do
    @documents
  end
end
