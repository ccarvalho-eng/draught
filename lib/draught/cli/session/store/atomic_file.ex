defmodule Draught.CLI.Session.Store.AtomicFile do
  @moduledoc """
  Publishes bounded owner-only session records through same-filesystem atomic operations.

  Temporary files live beside session directories and are created exclusively,
  synchronized, and removed after every outcome.
  """

  alias Draught.CLI.Storage.Directory

  @mode 0o600

  @type publication :: :create | :replace
  @type error :: :io | :publication_unknown

  @doc "Atomically creates or replaces one owner-only session record."
  @spec write(String.t(), binary(), publication(), String.t()) :: :ok | {:error, error()}
  def write(path, content, publication, prefix)
      when is_binary(content) and publication in [:create, :replace] and is_binary(prefix) do
    temporary = temporary_path(path, prefix)

    try do
      with {:ok, device} <- File.open(temporary, [:write, :binary, :exclusive]),
           :ok <- write_open(device, temporary, content) do
        publish_and_sync(temporary, path, publication)
      else
        _result -> {:error, :io}
      end
    after
      File.rm(temporary)
    end
  end

  defp publish(temporary, path, :create) do
    File.ln(temporary, path)
  end

  defp publish(temporary, path, :replace) do
    File.rename(temporary, path)
  end

  defp publish_and_sync(temporary, path, publication) do
    case publish(temporary, path, publication) do
      :ok -> Directory.sync_parent(path)
      {:error, _reason} -> {:error, :io}
    end
  end

  defp write_open(device, path, content) do
    result =
      with :ok <- File.chmod(path, @mode),
           :ok <- IO.binwrite(device, content) do
        :file.sync(device)
      end

    result
  after
    File.close(device)
  end

  defp temporary_path(path, prefix) do
    token =
      12
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    sessions_directory =
      path
      |> Path.dirname()
      |> Path.dirname()

    Path.join(sessions_directory, ".#{prefix}-#{token}.tmp")
  end
end
