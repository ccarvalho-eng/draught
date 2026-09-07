defmodule Draught.CLI.Task.Named do
  @moduledoc """
  Dispatches creation or continuation of one persistent named CLI task.
  """

  alias Draught.CLI.Task.Named.Create
  alias Draught.CLI.Task.Named.Resume

  @doc "Executes one create or resume turn while holding the named session lease."
  @spec run(
          Draught.CLI.Session.Store.mode(),
          String.t(),
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          map(),
          Draught.CLI.Task.Dependencies.t()
        ) :: Draught.CLI.Task.result()
  def run(:create, identifier, prompt, configuration, workspace, environment, dependencies) do
    Create.run(identifier, prompt, configuration, workspace, environment, dependencies)
  end

  def run(:resume, identifier, prompt, configuration, workspace, environment, dependencies) do
    Resume.run(identifier, prompt, configuration, workspace, environment, dependencies)
  end
end
