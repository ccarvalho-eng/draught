defmodule Draught.CLI.Dependencies do
  @moduledoc """
  Holds explicit effect adapters used at the CLI boundary.
  """

  alias Draught.CLI.System.Local
  alias Draught.Provider.Ollama.Discovery.HTTP.Req
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:discovery_http, :system]
  defstruct [:discovery_http, :system]

  @type system :: {module(), term()}
  @type t :: %__MODULE__{discovery_http: module(), system: system()}

  @doc "Builds and validates CLI effect dependencies."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:discovery_http, :system]),
         {:ok, system} <- system(Map.get(normalized, :system, {Local, nil})),
         {:ok, discovery_http} <-
           discovery_http(Map.get(normalized, :discovery_http, Req)) do
      {:ok, %__MODULE__{discovery_http: discovery_http, system: system}}
    end
  end

  defp system({module, configuration} = adapter) when is_atom(module) do
    callbacks = [
      cwd: 1,
      environment: 1,
      read_file: 3,
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

  defp discovery_http(module) when is_atom(module) do
    module
    |> implements?(request: 4)
    |> discovery_http_result(module)
  end

  defp discovery_http(_module) do
    Error.single([:discovery_http], :invalid_value, "must implement Ollama discovery HTTP")
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
end
