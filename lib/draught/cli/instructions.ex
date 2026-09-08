defmodule Draught.CLI.Instructions do
  @moduledoc """
  Loads bounded user and workspace guidance for a fresh CLI task.

  Guidance changes only the canonical system message. Tool availability,
  approvals, web access, workspace confinement, and provider configuration
  remain owned by their independent harness boundaries.
  """

  alias Draught.CLI.Instructions.Bundle
  alias Draught.CLI.Instructions.Loader
  alias Draught.CLI.Task.Preparation
  alias Draught.Error.Normalized

  @doc "Loads and composes the effective guidance for one fresh task."
  @spec load(String.t(), {module(), term()}) ::
          {:ok, String.t()} | {:error, Normalized.t()}
  def load(workspace, system) do
    with {:ok, bundle} <- Loader.load(workspace, system) do
      Bundle.render(bundle, Preparation.system_prompt())
    end
  end
end
