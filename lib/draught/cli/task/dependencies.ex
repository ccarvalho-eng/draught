defmodule Draught.CLI.Task.Dependencies do
  @moduledoc """
  Holds effect boundaries used by one-shot task execution.
  """

  alias Draught.CLI.Session.Identifier
  alias Draught.CLI.Task.Provider.Local
  alias Draught.Provider.OpenAI.Transport
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:identifier, :provider]
  defstruct [:identifier, :provider]

  @type identifier_generator :: (-> {:ok, String.t()} | {:error, term()})
  @type provider :: {module(), term()}
  @type t :: %__MODULE__{identifier: identifier_generator(), provider: provider()}

  @doc "Builds task dependencies from explicit overrides and shared discovery HTTP."
  @spec new(map() | keyword(), module()) :: Error.result(t())
  def new(attributes, discovery_http) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:identifier, :provider]),
         {:ok, identifier} <- identifier(Map.get(normalized, :identifier, &Identifier.generate/0)),
         {:ok, provider} <-
           provider(
             Map.get(normalized, :provider, {
               Local,
               [
                 discovery_http: discovery_http,
                 provider_transport: {Transport.Req, nil}
               ]
             })
           ) do
      {:ok, %__MODULE__{identifier: identifier, provider: provider}}
    end
  end

  defp identifier(generator) when is_function(generator, 0) do
    {:ok, generator}
  end

  defp identifier(_generator) do
    Error.single([:identifier], :invalid_value, "must be a function with arity zero")
  end

  defp provider({module, _configuration} = adapter) when is_atom(module) do
    valid = Code.ensure_loaded?(module) and function_exported?(module, :build, 2)
    provider_result(valid, adapter)
  end

  defp provider(_adapter) do
    invalid_provider()
  end

  defp provider_result(true, adapter) do
    {:ok, adapter}
  end

  defp provider_result(false, _adapter) do
    invalid_provider()
  end

  defp invalid_provider do
    Error.single([:provider], :invalid_value, "must implement the task provider boundary")
  end
end
