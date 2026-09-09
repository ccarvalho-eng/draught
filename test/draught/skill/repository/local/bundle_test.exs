defmodule Draught.Skill.Repository.Local.BundleTest do
  use ExUnit.Case, async: true

  alias Draught.Skill.Repository.Local.Bundle

  @tag :tmp_dir
  test "appends direct Markdown references in deterministic order", %{tmp_dir: directory} do
    write_entry(directory)
    write_reference(directory, "second.md", "Second reference")
    write_reference(directory, "first.md", "First reference")

    assert {:ok, content} = Bundle.complete(directory, 32_768)
    assert content =~ "Bundled reference: references/first.md"
    assert content =~ "Bundled reference: references/second.md"

    assert content =~
             ~r/references\/first\.md.*references\/second\.md/s
  end

  @tag :tmp_dir
  test "rejects unsafe, excessive, and cumulatively oversized references", %{
    tmp_dir: directory
  } do
    write_entry(directory)
    parent = Path.dirname(directory)
    outside = Path.join(parent, "outside.md")
    File.write!(outside, "Outside")
    references = references(directory)
    linked_reference = Path.join(references, "linked.md")
    File.ln_s!(outside, linked_reference)

    assert Bundle.complete(directory, 32_768) == {:error, :unsafe_file}

    File.rm!(linked_reference)

    Enum.each(1..17, fn index ->
      write_reference(directory, "reference-#{index}.md", "Reference")
    end)

    assert Bundle.complete(directory, 32_768) == {:error, :too_many_entries}

    Enum.each(1..17, fn index ->
      File.rm!(Path.join(references, "reference-#{index}.md"))
    end)

    Enum.each(1..3, fn index ->
      write_reference(directory, "large-#{index}.md", String.duplicate("x", 20_000))
    end)

    assert Bundle.complete(directory, 32_768) == {:error, :too_large}
  end

  defp write_entry(directory) do
    content = "---\nname: sample\ndescription: Sample\n---\nInstructions"

    directory
    |> Path.join("SKILL.md")
    |> File.write!(content)
  end

  defp write_reference(directory, name, content) do
    directory
    |> references()
    |> Path.join(name)
    |> File.write!(content)
  end

  defp references(directory) do
    path = Path.join(directory, "references")
    File.mkdir_p!(path)
    path
  end
end
