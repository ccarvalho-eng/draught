defmodule Draught.Tool.Builtin.ReplaceInFile.Operation do
  @moduledoc """
  Performs one bounded exact-text replacement for the mutation queue.

  The expected text must occur exactly once, and both the source and resulting
  file remain within the mutation byte limit before atomic replacement.
  """

  @behaviour Draught.Tool.Mutation.Operation

  alias Draught.Error.Normalized
  alias Draught.Tool.Builtin.ReadFile.Reader
  alias Draught.Tool.Builtin.ReplaceInFile.AtomicWriter

  @maximum_file_bytes 1_048_576

  @impl Draught.Tool.Mutation.Operation
  def run(%{path: path, expected: expected, replacement: replacement}) do
    with :ok <- expected(expected),
         {:ok, content} <- Reader.read(path, @maximum_file_bytes),
         {:ok, updated} <- replace_once(content, expected, replacement),
         :ok <- updated_size(updated),
         :ok <- AtomicWriter.write(path, updated) do
      {:ok, "Replaced one occurrence"}
    else
      {:error, %Normalized{}} = result -> result
      _failure -> failure("write_failed", "File replacement failed")
    end
  end

  defp expected(expected) do
    expected
    |> byte_size()
    |> then(&(&1 > 0))
    |> expected_result()
  end

  defp expected_result(true) do
    :ok
  end

  defp expected_result(false) do
    failure("invalid_replacement", "Expected text must not be empty")
  end

  defp replace_once(content, expected, replacement) do
    case :binary.matches(content, expected) do
      [{offset, length}] ->
        prefix = binary_part(content, 0, offset)
        suffix_offset = offset + length
        suffix = binary_part(content, suffix_offset, byte_size(content) - suffix_offset)
        {:ok, prefix <> replacement <> suffix}

      [] ->
        failure("expected_text_not_found", "Expected text was not found")

      [_first | _rest] ->
        failure("ambiguous_replacement", "Expected text occurs more than once")
    end
  end

  defp updated_size(updated) do
    updated
    |> byte_size()
    |> then(&(&1 <= @maximum_file_bytes))
    |> updated_size_result()
  end

  defp updated_size_result(true) do
    :ok
  end

  defp updated_size_result(false) do
    failure("replacement_too_large", "Updated file exceeds the mutation limit")
  end

  defp failure(code, message) do
    {:ok, error} = Normalized.new(:tool, code, message, retryable: false)
    {:error, error}
  end
end
