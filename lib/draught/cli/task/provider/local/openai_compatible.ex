defmodule Draught.CLI.Task.Provider.Local.OpenAICompatible do
  @moduledoc false

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Credential
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Provider.OpenAI
  alias Draught.Validation.Error

  @doc "Builds one trusted OpenAI-compatible adapter."
  @spec build(Configuration.t(), map()) :: Draught.CLI.Task.Provider.Adapter.result()
  def build(%Configuration{model: nil}, _dependencies) do
    Error.single([:model], :required, "is required for an OpenAI-compatible provider")
  end

  def build(%Configuration{} = configuration, dependencies) do
    options = [
      base_url: configuration.base_url,
      model: configuration.model,
      credential: credential(configuration.credential),
      headers: configuration.headers
    ]

    transport = Map.get(dependencies, :provider_transport)

    with {:ok, adapter} <- OpenAI.new(options, transport) do
      Selection.new(adapter, configuration.model)
    end
  end

  defp credential(nil) do
    nil
  end

  defp credential(%Credential{} = credential) do
    Credential.value(credential)
  end
end
