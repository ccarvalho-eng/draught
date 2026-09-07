defmodule Draught.CLI.Session.Binding do
  @moduledoc """
  Records the non-secret provider identity required to resume a named CLI session safely.

  A binding fixes the profile, provider connection fingerprint, adapter, and exact model without persisting credentials or raw headers.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Task.Preparation

  @schema "draught.cli.session/v1"
  @enforce_keys [:adapter, :connection, :model, :profile, :provider]
  defstruct [:adapter, :connection, :model, :profile, :provider]

  @type t :: %__MODULE__{
          adapter: String.t(),
          connection: String.t(),
          model: String.t(),
          profile: String.t(),
          provider: String.t()
        }

  @doc "Builds the non-secret identity binding for a prepared named session."
  @spec new(Configuration.t(), Preparation.t()) :: t()
  def new(%Configuration{} = configuration, %Preparation{} = preparation) do
    %__MODULE__{
      adapter: adapter(preparation),
      connection: connection(configuration),
      model: preparation.request.model,
      profile: configuration.profile,
      provider: Atom.to_string(configuration.provider)
    }
  end

  @doc "Applies a recorded model only when the current connection identity matches."
  @spec bind_configuration(t(), Configuration.t()) ::
          {:ok, Configuration.t()} | {:error, Draught.Error.Normalized.t()}
  def bind_configuration(%__MODULE__{} = binding, %Configuration{} = configuration) do
    current =
      {configuration.profile, Atom.to_string(configuration.provider), connection(configuration)}

    recorded = {binding.profile, binding.provider, binding.connection}
    bind_model(current == recorded, binding, configuration)
  end

  @doc "Verifies the exact selected model and adapter after provider construction."
  @spec verify(t(), Preparation.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def verify(%__MODULE__{} = binding, %Preparation{} = preparation) do
    current = {adapter(preparation), preparation.request.model}
    expected = {binding.adapter, binding.model}

    verify_result(current == expected)
  end

  @doc "Encodes a binding as one versioned JSON object."
  @spec encode(t()) :: {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(%__MODULE__{} = binding) do
    value = %{
      "adapter" => binding.adapter,
      "connection" => binding.connection,
      "model" => binding.model,
      "profile" => binding.profile,
      "provider" => binding.provider,
      "schema" => @schema
    }

    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, _error} -> {:error, Failure.invalid_binding()}
    end
  end

  @doc "Decodes the closed versioned binding representation."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(encoded) when is_binary(encoded) do
    case Jason.decode(encoded) do
      {:ok, value} -> decode_value(value)
      {:error, _error} -> {:error, Failure.invalid_binding()}
    end
  end

  def decode(_encoded) do
    {:error, Failure.invalid_binding()}
  end

  defp decode_value(
         %{
           "adapter" => adapter,
           "connection" => connection,
           "model" => model,
           "profile" => profile,
           "provider" => provider,
           "schema" => @schema
         } = value
       )
       when map_size(value) == 6 and is_binary(adapter) and is_binary(connection) and
              is_binary(model) and is_binary(profile) and is_binary(provider) do
    valid =
      Enum.all?([adapter, model, profile, provider], &(byte_size(&1) > 0)) and
        byte_size(connection) == 64

    decode_result(valid, adapter, connection, model, profile, provider)
  end

  defp decode_value(_value) do
    {:error, Failure.invalid_binding()}
  end

  defp decode_result(true, adapter, connection, model, profile, provider) do
    {:ok,
     %__MODULE__{
       adapter: adapter,
       connection: connection,
       model: model,
       profile: profile,
       provider: provider
     }}
  end

  defp decode_result(false, _adapter, _connection, _model, _profile, _provider) do
    {:error, Failure.invalid_binding()}
  end

  defp bind_model(false, _binding, _configuration) do
    {:error, Failure.binding_mismatch()}
  end

  defp bind_model(true, binding, %Configuration{model: nil} = configuration) do
    {:ok, %{configuration | model: binding.model}}
  end

  defp bind_model(true, binding, %Configuration{model: model} = configuration) do
    bind_model_result(model == binding.model, configuration)
  end

  defp bind_model_result(true, configuration) do
    {:ok, configuration}
  end

  defp bind_model_result(false, _configuration) do
    {:error, Failure.binding_mismatch()}
  end

  defp verify_result(true) do
    :ok
  end

  defp verify_result(false) do
    {:error, Failure.binding_mismatch()}
  end

  defp adapter(%Preparation{runner: %{provider: {module, _configuration}}}) do
    Atom.to_string(module)
  end

  defp connection(%Configuration{} = configuration) do
    headers =
      configuration.headers
      |> Enum.sort()
      |> Enum.flat_map(fn {name, value} -> [name, value] end)

    [configuration.base_url | headers]
    |> Enum.map_join(&frame/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp frame(value) do
    size =
      value
      |> byte_size()
      |> Integer.to_string()

    [size, ":", value]
  end
end
