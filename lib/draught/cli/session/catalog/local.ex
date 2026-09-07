defmodule Draught.CLI.Session.Catalog.Local do
  @moduledoc """
  Implements workspace-local session discovery and leased metadata mutations.
  """

  @behaviour Draught.CLI.Session.Catalog.Adapter

  alias Draught.CLI.Session.Catalog.Mutation
  alias Draught.CLI.Session.Catalog.Scanner
  alias Draught.CLI.Session.Store.Scope

  @impl Draught.CLI.Session.Catalog.Adapter
  def list(workspace, environment, _configuration) do
    with {:ok, scope} <- Scope.new(workspace, environment) do
      Scanner.list(scope)
    end
  end

  @impl Draught.CLI.Session.Catalog.Adapter
  def fetch(workspace, identifier, environment, _configuration) do
    with {:ok, scope} <- Scope.new(workspace, environment) do
      Scanner.fetch(scope, identifier)
    end
  end

  @impl Draught.CLI.Session.Catalog.Adapter
  def rename(workspace, identifier, label, environment, configuration) do
    Mutation.run(workspace, identifier, environment, {:rename, label}, configuration)
  end

  @impl Draught.CLI.Session.Catalog.Adapter
  def archive(workspace, identifier, environment, configuration) do
    Mutation.run(workspace, identifier, environment, :archive, configuration)
  end

  @impl Draught.CLI.Session.Catalog.Adapter
  def restore(workspace, identifier, environment, configuration) do
    Mutation.run(workspace, identifier, environment, :restore, configuration)
  end
end
