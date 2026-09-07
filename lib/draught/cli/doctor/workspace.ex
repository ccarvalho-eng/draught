defmodule Draught.CLI.Doctor.Workspace do
  @moduledoc """
  Performs the read-only workspace accessibility check used by CLI diagnostics.
  """

  alias Draught.CLI.Doctor.Check

  @doc "Checks whether the current workspace is an accessible read-write directory."
  @spec check(String.t(), module(), term()) :: Check.t()
  def check(workspace, system, system_configuration) do
    case system.workspace(workspace, system_configuration) do
      :ok ->
        Check.new("Workspace", :ok, "accessible")

      {:error, :not_directory} ->
        Check.new("Workspace", :error, "current path is not a directory")

      {:error, :inaccessible} ->
        Check.new("Workspace", :error, "current directory is not accessible")
    end
  end
end
