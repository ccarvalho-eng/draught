defmodule Draught.CLI.Dependencies do
  @moduledoc """
  Holds explicit effect adapters used at the CLI boundary.
  """

  alias Draught.CLI.Dependencies.Defaults
  alias Draught.CLI.Task.Dependencies
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:catalog, :discovery_http, :skill_repository, :system, :task, :terminal]
  defstruct [:catalog, :discovery_http, :skill_repository, :system, :task, :terminal]

  @type system :: {module(), term()}
  @type t :: %__MODULE__{
          catalog: {module(), term()},
          discovery_http: module(),
          skill_repository: {module(), term()},
          system: system(),
          task: Dependencies.t(),
          terminal: system()
        }

  @doc "Builds and validates CLI effect dependencies."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    keys = [:catalog, :discovery_http, :skill_repository, :system, :task, :terminal]

    with {:ok, normalized} <- Attributes.normalize(attributes, keys) do
      build(normalized)
    end
  end

  defp build(attributes) do
    with {:ok, catalog} <- configured_catalog(attributes),
         {:ok, system} <- configured_system(attributes) do
      build_remaining(attributes, catalog, system)
    end
  end

  defp build_remaining(attributes, catalog, system) do
    with {:ok, skill_repository} <- configured_skill_repository(attributes),
         {:ok, terminal} <- configured_terminal(attributes),
         {:ok, discovery_http} <- configured_discovery_http(attributes),
         {:ok, task} <- task(attributes, discovery_http) do
      {:ok,
       %__MODULE__{
         catalog: catalog,
         discovery_http: discovery_http,
         skill_repository: skill_repository,
         system: system,
         task: task,
         terminal: terminal
       }}
    end
  end

  defp configured_catalog(attributes) do
    attributes
    |> Map.get(:catalog, Defaults.catalog())
    |> catalog()
  end

  defp configured_system(attributes) do
    attributes
    |> Map.get(:system, Defaults.system())
    |> system()
  end

  defp configured_terminal(attributes) do
    attributes
    |> Map.get(:terminal, Defaults.terminal())
    |> terminal()
  end

  defp configured_skill_repository(attributes) do
    attributes
    |> Map.get(:skill_repository, Defaults.skill_repository())
    |> skill_repository()
  end

  defp configured_discovery_http(attributes) do
    attributes
    |> Map.get(:discovery_http, Defaults.discovery_http())
    |> discovery_http()
  end

  defp system({module, configuration} = adapter) when is_atom(module) do
    callbacks = [
      cwd: 1,
      environment: 1,
      read_file: 3,
      write_file: 3,
      workspace: 2,
      write: 3,
      tty?: 2,
      columns: 1
    ]

    module
    |> implements?(callbacks)
    |> system_result(adapter, configuration)
  end

  defp system(_adapter) do
    Error.single([:system], :invalid_value, "must implement the CLI system boundary")
  end

  defp catalog({module, _configuration} = adapter) when is_atom(module) do
    valid =
      implements?(module,
        fetch: 4,
        list: 3,
        rename: 5,
        archive: 4,
        restore: 4
      )

    catalog_result(valid, adapter)
  end

  defp catalog(_adapter) do
    Error.single([:catalog], :invalid_value, "must implement the session catalog boundary")
  end

  defp discovery_http(module) when is_atom(module) do
    module
    |> implements?(request: 4)
    |> discovery_http_result(module)
  end

  defp discovery_http(_module) do
    Error.single([:discovery_http], :invalid_value, "must implement Ollama discovery HTTP")
  end

  defp skill_repository({module, _configuration} = adapter) when is_atom(module) do
    module
    |> implements?(list: 3, fetch: 4)
    |> skill_repository_result(adapter)
  end

  defp skill_repository(_adapter) do
    invalid_skill_repository()
  end

  defp terminal({module, configuration} = adapter) when is_atom(module) do
    module
    |> implements?(interactive?: 1, read_line: 1, restore: 1)
    |> terminal_result(adapter, configuration)
  end

  defp terminal(_adapter) do
    Error.single([:terminal], :invalid_value, "must implement the interactive terminal boundary")
  end

  defp task(attributes, discovery_http) do
    attributes
    |> Map.get(:task, [])
    |> Dependencies.new(discovery_http)
  end

  defp implements?(module, callbacks) do
    Code.ensure_loaded?(module) and
      Enum.all?(callbacks, fn {name, arity} -> function_exported?(module, name, arity) end)
  end

  defp system_result(true, adapter, _configuration) do
    {:ok, adapter}
  end

  defp system_result(false, _adapter, _configuration) do
    Error.single([:system], :invalid_value, "must implement the CLI system boundary")
  end

  defp discovery_http_result(true, module) do
    {:ok, module}
  end

  defp discovery_http_result(false, _module) do
    Error.single([:discovery_http], :invalid_value, "must implement Ollama discovery HTTP")
  end

  defp skill_repository_result(true, adapter) do
    {:ok, adapter}
  end

  defp skill_repository_result(false, _adapter) do
    invalid_skill_repository()
  end

  defp invalid_skill_repository do
    Error.single(
      [:skill_repository],
      :invalid_value,
      "must implement the skill repository boundary"
    )
  end

  defp catalog_result(true, adapter) do
    {:ok, adapter}
  end

  defp catalog_result(false, _adapter) do
    Error.single([:catalog], :invalid_value, "must implement the session catalog boundary")
  end

  defp terminal_result(true, adapter, _configuration) do
    {:ok, adapter}
  end

  defp terminal_result(false, _adapter, _configuration) do
    Error.single([:terminal], :invalid_value, "must implement the interactive terminal boundary")
  end
end
