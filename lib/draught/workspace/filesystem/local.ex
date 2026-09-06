defmodule Draught.Workspace.Filesystem.Local do
  @moduledoc """
  Uses the local filesystem for workspace path metadata.
  """

  @behaviour Draught.Workspace.Filesystem

  @impl Draught.Workspace.Filesystem
  def lstat(path, _configuration) do
    File.lstat(path)
  end

  @impl Draught.Workspace.Filesystem
  def read_link(path, _configuration) do
    File.read_link(path)
  end
end
