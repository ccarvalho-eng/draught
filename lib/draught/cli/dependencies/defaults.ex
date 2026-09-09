defmodule Draught.CLI.Dependencies.Defaults do
  @moduledoc """
  Provides the production adapters for the CLI dependency container.
  """

  @doc "Returns the local session catalog adapter."
  @spec catalog() :: {module(), nil}
  def catalog do
    {Draught.CLI.Session.Catalog.Local, nil}
  end

  @doc "Returns the provider-discovery HTTP adapter."
  @spec discovery_http() :: module()
  def discovery_http do
    Draught.Provider.Ollama.Discovery.HTTP.Req
  end

  @doc "Returns the local skill repository adapter."
  @spec skill_repository() :: {module(), nil}
  def skill_repository do
    {Draught.Skill.Repository.Local, nil}
  end

  @doc "Returns the local CLI system adapter."
  @spec system() :: {module(), nil}
  def system do
    {Draught.CLI.System.Local, nil}
  end

  @doc "Returns the local interactive terminal adapter."
  @spec terminal() :: {module(), nil}
  def terminal do
    {Draught.CLI.Interactive.Terminal.Local, nil}
  end
end
