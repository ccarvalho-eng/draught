defmodule Draught.CLI.Session.Catalog.Scanner.DirectoryListing do
  @moduledoc """
  Enumerates catalog names inside a heap- and time-bounded supervised task.

  Filesystem directory APIs materialize their complete result. Isolation keeps
  that allocation outside the CLI process and converts excessive enumeration,
  task failure, and deadline expiry into bounded catalog failures.
  """

  alias Draught.CLI.Session.Failure
  alias Draught.Execution.BoundedTask

  @heap_words 65_536
  @maximum_entries 256
  @timeout_ms 5_000

  @doc "Lists at most the configured catalog entry count in deterministic order."
  @spec list(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list(directory) do
    BoundedTask.run(
      fn -> isolated_list(directory) end,
      @timeout_ms,
      Failure.storage_unavailable(),
      Failure.catalog_too_large()
    )
  end

  defp isolated_list(directory) do
    Process.flag(
      :max_heap_size,
      %{error_logger: false, kill: true, size: @heap_words}
    )

    case File.ls(directory) do
      {:ok, names} -> bounded(names)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp bounded(names) do
    case Enum.split(names, @maximum_entries) do
      {bounded, []} -> {:ok, Enum.sort(bounded)}
      {_bounded, [_entry | _entries]} -> {:error, Failure.catalog_too_large()}
    end
  end
end
