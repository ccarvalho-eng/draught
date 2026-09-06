defmodule Draught.Workspace.Filesystem do
  @moduledoc """
  Defines filesystem metadata operations used during path resolution.
  """

  @type config :: term()
  @type result(value) :: {:ok, value} | {:error, term()}

  @doc "Reads path metadata without following the final symlink."
  @callback lstat(String.t(), config()) :: result(File.Stat.t())

  @doc "Reads the target stored in a symbolic link."
  @callback read_link(String.t(), config()) :: result(String.t())
end
