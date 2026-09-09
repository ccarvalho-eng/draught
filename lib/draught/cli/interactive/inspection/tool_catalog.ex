defmodule Draught.CLI.Interactive.Inspection.ToolCatalog do
  @moduledoc """
  Builds a display-safe projection of the effective built-in tool catalog.

  The projection contains no executors, adapter configuration, schemas, or web
  endpoint details.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Preparation.Web
  alias Draught.CLI.Task.Web.Setting
  alias Draught.Tool.Builtin
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @type entry :: %{
          required(:description) => String.t(),
          required(:name) => String.t(),
          required(:risk) => Draught.Tool.Risk.t()
        }
  @type t :: %{
          required(:entries) => [entry()],
          required(:web_fetch) => boolean(),
          required(:web_search) => boolean()
        }

  @doc "Returns enabled built-in metadata and explicit optional web-tool state."
  @spec build(Configuration.t()) :: {:ok, t()} | {:error, Error.t()}
  def build(%Configuration{} = configuration) do
    with {:ok, capability} <-
           configuration
           |> Setting.from_configuration()
           |> Web.capability(),
         {:ok, definitions} <- Builtin.definitions(web: capability) do
      {:ok,
       %{
         entries: Enum.map(definitions, &entry/1),
         web_fetch: configuration.web,
         web_search: configuration.web_search
       }}
    end
  end

  defp entry(%Definition{} = definition) do
    %{
      description: definition.specification.description,
      name: definition.specification.name,
      risk: definition.risk
    }
  end
end
