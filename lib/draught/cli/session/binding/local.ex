defmodule Draught.CLI.Session.Binding.Local do
  @moduledoc false

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Session.Journal.Local.SafeFile

  @maximum_bytes 4_096
  @mode 0o600

  @doc "Atomically writes a new owner-only session binding."
  @spec create(Paths.t(), Binding.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def create(%Paths{} = paths, %Binding{} = binding) do
    with {:ok, encoded} <- Binding.encode(binding) do
      atomic_create(paths.binding, encoded)
    end
  end

  @doc "Reads one bounded regular owner-only session binding."
  @spec read(Paths.t()) :: {:ok, Binding.t()} | {:error, Draught.Error.Normalized.t()}
  def read(%Paths{} = paths) do
    case SafeFile.read(paths.binding, @maximum_bytes) do
      {:ok, encoded} -> Binding.decode(encoded)
      {:error, _reason} -> {:error, Failure.invalid_binding()}
    end
  end

  defp atomic_create(path, content) do
    temporary = temporary_path(path)

    try do
      with {:ok, device} <- File.open(temporary, [:write, :binary, :exclusive]),
           :ok <- write(device, temporary, content),
           :ok <- File.ln(temporary, path) do
        :ok
      else
        _result -> {:error, Failure.storage_unavailable()}
      end
    after
      File.rm(temporary)
    end
  end

  defp write(device, path, content) do
    result =
      with :ok <- File.chmod(path, @mode),
           :ok <- IO.binwrite(device, content) do
        :file.sync(device)
      end

    result
  after
    File.close(device)
  end

  defp temporary_path(path) do
    token =
      12
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    sessions_directory =
      path
      |> Path.dirname()
      |> Path.dirname()

    Path.join(sessions_directory, ".binding-#{token}.tmp")
  end
end
