defmodule Draught.Skill.Repository.Local.Bundle do
  @moduledoc """
  Loads one packaged skill and its direct Markdown references under fixed bounds.

  References are appended in filename order and never expose their application
  filesystem location to the model.
  """

  alias Draught.Skill.Repository.Local.File

  @maximum_bundle_bytes 60_000
  @maximum_reference_bytes 24_576
  @maximum_references 16
  @reference_name ~r/\A[a-z0-9][a-z0-9_-]*\.md\z/

  @doc "Reads one complete built-in skill bundle under cumulative size and count limits."
  @spec complete(String.t(), pos_integer()) :: {:ok, String.t()} | {:error, atom()}
  def complete(directory, maximum_entry_bytes)
      when is_binary(directory) and is_integer(maximum_entry_bytes) and
             maximum_entry_bytes > 0 do
    entry_path = Path.join(directory, "SKILL.md")

    with {:ok, entry} <- File.complete(entry_path, maximum_entry_bytes),
         {:ok, names} <- reference_names(directory) do
      append_references(names, directory, entry)
    end
  end

  defp reference_names(directory) do
    directory
    |> Path.join("references")
    |> File.entries(@maximum_references)
    |> validate_names()
  end

  defp validate_names({:ok, names}) do
    markdown = Enum.filter(names, &(Path.extname(&1) == ".md"))
    valid = Enum.all?(markdown, &Regex.match?(@reference_name, &1))
    validated_names(valid, markdown)
  end

  defp validate_names({:error, reason}) do
    {:error, reason}
  end

  defp validated_names(true, markdown) do
    {:ok, markdown}
  end

  defp validated_names(false, _markdown) do
    {:error, :invalid_reference}
  end

  defp append_references(names, directory, entry) do
    Enum.reduce_while(names, {:ok, entry}, fn name, {:ok, content} ->
      append_reference(directory, name, content)
    end)
  end

  defp append_reference(directory, name, content) do
    path = Path.join([directory, "references", name])

    case File.complete(path, @maximum_reference_bytes) do
      {:ok, reference} -> append(content, name, reference)
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp append(content, name, reference) do
    combined =
      IO.iodata_to_binary([
        content,
        "\n\n## Bundled reference: references/",
        name,
        "\n\n",
        reference
      ])

    combined
    |> byte_size()
    |> Kernel.<=(@maximum_bundle_bytes)
    |> append_result(combined)
  end

  defp append_result(true, combined) do
    {:cont, {:ok, combined}}
  end

  defp append_result(false, _combined) do
    {:halt, {:error, :too_large}}
  end
end
