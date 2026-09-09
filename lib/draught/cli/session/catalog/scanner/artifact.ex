defmodule Draught.CLI.Session.Catalog.Scanner.Artifact do
  @moduledoc """
  Recognizes safe orphan records from interrupted atomic session writes.

  Known temporary files are ignored by read-only discovery. Their exact name,
  regular-file shape, owner-only permissions, and bounded size are validated so
  arbitrary catalog entries cannot hide behind the temporary-file convention.
  """

  import Bitwise

  alias Draught.CLI.Session.Failure

  @maximum_bytes 4_096
  @mode 0o600
  @name ~r/\A\.(?:binding|metadata|preview)-[A-Za-z0-9_-]{16}\.tmp\z/

  @doc "Accepts one bounded owner-only atomic-write artifact."
  @spec validate(String.t(), String.t()) :: :ok | {:error, term()}
  def validate(directory, name) when is_binary(name) do
    name
    |> String.valid?()
    |> validate_encoding(directory, name)
  end

  defp validate_encoding(true, directory, name) do
    @name
    |> Regex.match?(name)
    |> validate_name(directory, name)
  end

  defp validate_encoding(false, _directory, _name) do
    {:error, Failure.storage_unsafe()}
  end

  defp validate_name(true, directory, name) do
    path = Path.join(directory, name)

    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode, size: size}}
      when band(mode, 0o777) == @mode and size <= @maximum_bytes ->
        :ok

      {:ok, %File.Stat{}} ->
        {:error, Failure.storage_unsafe()}

      {:error, _reason} ->
        {:error, Failure.storage_unavailable()}
    end
  end

  defp validate_name(false, _directory, _name) do
    {:error, Failure.storage_unsafe()}
  end
end
