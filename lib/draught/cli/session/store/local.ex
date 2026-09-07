defmodule Draught.CLI.Session.Store.Local do
  @moduledoc false

  import Bitwise

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Error.Normalized

  @marker_contents "draught-session/v1\n"
  @marker_mode 0o600
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
    case File.lstat(paths.session) do
      {:error, :enoent} -> create_missing(paths)
      {:ok, %File.Stat{}} -> existing_session(paths)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  @doc "Validates an existing owner-only session directory without creating it."
  @spec validate(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def validate(%Paths{} = paths) do
    with :ok <- validate_session_directory(paths.session) do
      validate_marker(paths.marker)
    end
  end

  @doc "Removes only a newly created marker-only session directory."
  @spec abort(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def abort(%Paths{} = paths) do
    with :ok <- validate(paths),
         {:ok, [".draught-session"]} <- File.ls(paths.session),
         :ok <- remove_marker(paths.marker, true) do
      remove_session(paths.session)
    else
      {:error, %Normalized{} = error} -> {:error, error}
      _result -> {:error, Failure.storage_unsafe()}
    end
  end

  @doc "Creates a named session, recovering only an interrupted marker-only initialization."
  @spec initialize(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def initialize(%Paths{} = paths) do
    case create(paths) do
      {:error, %Normalized{code: "session_already_exists"} = error} ->
        recover_uninitialized(paths, error)

      result ->
        result
    end
  end

  defp validate_session_directory(session) do
    case File.lstat(session) do
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

  defp recover_uninitialized(paths, error) do
    case File.ls(paths.session) do
      {:ok, [".draught-session"]} -> recover_marker_only(paths)
      {:ok, _entries} -> {:error, error}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp recover_marker_only(paths) do
    with :ok <- abort(paths) do
      create(paths)
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
      :ok ->
        {:error, Failure.exists()}

      {:error, %Normalized{code: "session_storage_unsafe"} = error} ->
        recover_incomplete(paths, error)

      {:error, _error} = result ->
        result
    end
  end

  defp create_missing(paths) do
    case File.mkdir(paths.session) do
      :ok -> initialize_session(paths)
      {:error, :eexist} -> existing_session(paths)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp initialize_session(paths) do
    with :ok <- owner_only(paths.session),
         :ok <- write_marker(paths.marker) do
      owner_only_marker(paths.marker)
    end
  end

  defp write_marker(marker) do
    case File.write(marker, @marker_contents, [:write, :exclusive, :sync]) do
      :ok -> :ok
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp owner_only_marker(marker) do
    case File.chmod(marker, @marker_mode) do
      :ok -> validate_marker(marker)
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp validate_marker(marker) do
    case File.lstat(marker) do
      {:ok, %File.Stat{type: :regular, mode: mode, size: size}}
      when band(mode, 0o777) == @marker_mode and size == byte_size(@marker_contents) ->
        marker_contents(marker)

      {:ok, %File.Stat{}} ->
        {:error, Failure.storage_unsafe()}

      {:error, :enoent} ->
        {:error, Failure.storage_unsafe()}

      {:error, _reason} ->
        {:error, Failure.storage_unavailable()}
    end
  end

  defp marker_contents(marker) do
    case File.read(marker) do
      {:ok, @marker_contents} -> :ok
      {:ok, _contents} -> {:error, Failure.storage_unsafe()}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp recover_incomplete(paths, error) do
    case File.lstat(paths.session) do
      {:ok, %File.Stat{type: :directory, mode: mode}}
      when band(mode, 0o777) == @owner_mode ->
        recover_directory(paths, error)

      {:ok, %File.Stat{type: :directory}} ->
        recover_unsecured_directory(paths, error)

      {:ok, %File.Stat{}} ->
        {:error, error}

      {:error, _reason} ->
        {:error, error}
    end
  end

  defp recover_unsecured_directory(paths, error) do
    case File.ls(paths.session) do
      {:ok, []} -> replace_incomplete(paths, false)
      {:ok, _entries} -> {:error, error}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp recover_directory(paths, error) do
    case File.ls(paths.session) do
      {:ok, []} -> replace_incomplete(paths, false)
      {:ok, [".draught-session"]} -> recover_partial_marker(paths, error)
      {:ok, _entries} -> {:error, error}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp recover_partial_marker(paths, error) do
    case File.lstat(paths.marker) do
      {:ok, %File.Stat{type: :regular, size: size}}
      when size <= byte_size(@marker_contents) ->
        inspect_partial_marker(paths, error)

      {:ok, %File.Stat{}} ->
        {:error, error}

      {:error, _reason} ->
        {:error, error}
    end
  end

  defp inspect_partial_marker(paths, error) do
    case File.read(paths.marker) do
      {:ok, @marker_contents} -> owner_only_marker(paths.marker)
      {:ok, contents} -> recover_marker_prefix(paths, error, marker_prefix?(contents))
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp recover_marker_prefix(paths, _error, true) do
    replace_incomplete(paths, true)
  end

  defp recover_marker_prefix(_paths, error, false) do
    {:error, error}
  end

  defp marker_prefix?(contents) when byte_size(contents) < byte_size(@marker_contents) do
    size = byte_size(contents)
    binary_part(@marker_contents, 0, size) == contents
  end

  defp marker_prefix?(_contents) do
    false
  end

  defp replace_incomplete(paths, remove_marker?) do
    with :ok <- remove_marker(paths.marker, remove_marker?),
         :ok <- remove_session(paths.session) do
      create_missing(paths)
    end
  end

  defp remove_marker(marker, true) do
    case File.rm(marker) do
      :ok -> :ok
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp remove_marker(_marker, false) do
    :ok
  end

  defp remove_session(session) do
    case File.rmdir(session) do
      :ok -> :ok
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
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
