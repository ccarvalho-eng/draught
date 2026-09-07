defmodule Draught.CLI.Session.Store.Local do
  @moduledoc false

  import Bitwise

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Paths

  @owner_mode 0o700

  @doc "Creates and validates the owner-only directories for one session."
  @spec prepare(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def prepare(%Paths{} = paths) do
    with :ok <- create_parent(paths.root) do
      paths
      |> directories()
      |> secure_directories()
    end
  end

  @doc "Creates a new owner-only session directory without opening an existing session."
  @spec create(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def create(%Paths{} = paths) do
    case File.mkdir(paths.session) do
      :ok -> owner_only(paths.session)
      {:error, :eexist} -> existing_session(paths)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  @doc "Validates an existing owner-only session directory without creating it."
  @spec validate(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def validate(%Paths{} = paths) do
    case File.lstat(paths.session) do
      {:ok, %File.Stat{type: :directory, mode: mode}}
      when band(mode, 0o777) == @owner_mode ->
        :ok

      {:ok, %File.Stat{}} ->
        {:error, Failure.storage_unsafe()}

      {:error, :enoent} ->
        {:error, Failure.missing()}

      {:error, _reason} ->
        {:error, Failure.storage_unavailable()}
    end
  end

  defp directories(paths) do
    [
      paths.root,
      Path.join(paths.root, "workspaces"),
      paths.workspace,
      Path.join(paths.workspace, "sessions")
    ]
  end

  defp existing_session(paths) do
    case validate(paths) do
      :ok -> {:error, Failure.exists()}
      {:error, _error} = result -> result
    end
  end

  defp create_parent(root) do
    result =
      root
      |> Path.dirname()
      |> File.mkdir_p()

    case result do
      :ok -> :ok
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp secure_directories(directories) do
    Enum.reduce_while(directories, :ok, fn directory, :ok ->
      case secure_directory(directory) do
        :ok -> {:cont, :ok}
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp secure_directory(directory) do
    case File.mkdir(directory) do
      :ok -> validate_directory(directory)
      {:error, :eexist} -> validate_directory(directory)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp validate_directory(directory) do
    case File.lstat(directory) do
      {:ok, %File.Stat{type: :directory}} -> owner_only(directory)
      {:ok, %File.Stat{}} -> {:error, Failure.storage_unsafe()}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp owner_only(directory) do
    case File.chmod(directory, @owner_mode) do
      :ok -> verify_mode(directory)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp verify_mode(directory) do
    case File.lstat(directory) do
      {:ok, %File.Stat{type: :directory, mode: mode}}
      when band(mode, 0o777) == @owner_mode ->
        :ok

      {:ok, %File.Stat{}} ->
        {:error, Failure.storage_unsafe()}

      {:error, _reason} ->
        {:error, Failure.storage_unavailable()}
    end
  end
end
