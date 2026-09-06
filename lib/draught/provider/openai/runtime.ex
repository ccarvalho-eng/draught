defmodule Draught.Provider.OpenAI.Runtime do
  @moduledoc """
  Holds validated provider configuration and an injected transport dependency.
  """

  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Transport
  alias Draught.Validation.Error

  @required_callbacks [complete: 2, stream: 4]

  @enforce_keys [:configuration, :transport_module, :transport_config]
  defstruct [:configuration, :transport_module, :transport_config]

  @type t :: %__MODULE__{
          configuration: Configuration.t(),
          transport_module: module(),
          transport_config: term()
        }

  @doc "Builds a runtime with the default Req transport or an explicit dependency."
  @spec new(map() | keyword() | Configuration.t(), term()) :: Error.result(t())
  def new(configuration, transport \\ {Transport.Req, nil}) do
    with {:ok, validated_configuration} <- configuration(configuration),
         {:ok, module, config} <- transport(transport) do
      {:ok,
       %__MODULE__{
         configuration: validated_configuration,
         transport_module: module,
         transport_config: config
       }}
    end
  end

  defp configuration(%Configuration{} = configuration) do
    configuration
    |> Map.from_struct()
    |> Configuration.new()
  end

  defp configuration(attributes) do
    Configuration.new(attributes)
  end

  defp transport({module, config}) when is_atom(module) do
    valid = Code.ensure_loaded?(module) and callbacks_exported?(module)
    transport_result(valid, module, config)
  end

  defp transport(_transport) do
    invalid_transport()
  end

  defp callbacks_exported?(module) do
    Enum.all?(@required_callbacks, fn {function, arity} ->
      function_exported?(module, function, arity)
    end)
  end

  defp transport_result(true, module, config) do
    {:ok, module, config}
  end

  defp transport_result(false, _module, _config) do
    invalid_transport()
  end

  defp invalid_transport do
    Error.single([:transport], :invalid_value, "must implement the OpenAI transport contract")
  end
end

defimpl Inspect, for: Draught.Provider.OpenAI.Runtime do
  import Inspect.Algebra

  @spec inspect(Draught.Provider.OpenAI.Runtime.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect(_runtime, _options) do
    concat(["#Draught.Provider.OpenAI.Runtime<redacted>"])
  end
end
