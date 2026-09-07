defmodule Draught.CLI.Session.Binding.Local do
  @moduledoc """
  Persists a bounded owner-only session binding with atomic no-replace publication.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.AtomicFile
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Session.Journal.Local.SafeFile

  @maximum_bytes 4_096
  @doc "Atomically writes a new owner-only session binding."
  @spec create(Paths.t(), Binding.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def create(%Paths{} = paths, %Binding{} = binding) do
    with {:ok, encoded} <- Binding.encode(binding) do
      atomic_write(paths.binding, encoded, :create)
    end
  end

  @doc "Atomically replaces an existing binding while preserving owner-only permissions."
  @spec replace(Paths.t(), Binding.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def replace(%Paths{} = paths, %Binding{} = binding) do
    with {:ok, encoded} <- Binding.encode(binding) do
      atomic_write(paths.binding, encoded, :replace)
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

  defp atomic_write(path, content, mode) do
    case AtomicFile.write(path, content, mode, "binding") do
      :ok -> :ok
      {:error, :io} -> {:error, Failure.storage_unavailable()}
      {:error, :publication_unknown} -> {:error, Failure.publication_unknown()}
    end
  end
end
