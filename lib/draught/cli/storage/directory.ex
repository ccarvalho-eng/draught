defmodule Draught.CLI.Storage.Directory do
  @moduledoc """
  Synchronizes local CLI storage directories after an atomic publication.
  """

  @doc "Synchronizes the parent directory containing a published file."
  @spec sync_parent(String.t()) :: :ok | {:error, :publication_unknown}
  def sync_parent(path) when is_binary(path) do
    directory =
      path
      |> Path.dirname()
      |> String.to_charlist()

    case :file.open(directory, [:read, :raw, :directory]) do
      {:ok, device} -> sync(device)
      {:error, _reason} -> {:error, :publication_unknown}
    end
  end

  defp sync(device) do
    result =
      case :file.sync(device) do
        :ok -> :ok
        {:error, _reason} -> {:error, :publication_unknown}
      end

    :file.close(device)
    result
  end
end
