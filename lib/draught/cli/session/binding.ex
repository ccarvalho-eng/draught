defmodule Draught.CLI.Session.Binding do
  @moduledoc """
  Records the non-secret provider identity required to resume a named CLI session safely.

  A binding fixes the profile, provider connection fingerprint, adapter,
  negotiated capabilities, and exact model without persisting credentials or
  raw headers.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Session.Binding.CapabilityIdentity
  alias Draught.CLI.Session.Binding.ConnectionIdentity
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Task.Preparation

  @legacy_schema "draught.cli.session/v1"
  @schema "draught.cli.session/v2"
  @enforce_keys [:adapter, :capabilities, :connection, :model, :profile, :provider, :version]
  defstruct [:adapter, :capabilities, :connection, :model, :profile, :provider, :version]

  @type t :: %__MODULE__{
          adapter: String.t(),
          capabilities: String.t() | nil,
          connection: String.t(),
          model: String.t(),
          profile: String.t(),
          provider: String.t(),
          version: 1 | 2
        }

  @doc "Builds the non-secret identity binding for a prepared named session."
  @spec new(Configuration.t(), Preparation.t()) :: t()
  def new(%Configuration{} = configuration, %Preparation{} = preparation) do
    %__MODULE__{
      adapter: adapter(preparation),
      capabilities:
        CapabilityIdentity.fingerprint(
          preparation.capabilities,
          preparation.runner.tool_context.web
        ),
      connection: ConnectionIdentity.fingerprint(configuration),
      model: preparation.request.model,
      profile: configuration.profile,
      provider: Atom.to_string(configuration.provider),
      version: 2
    }
  end

  @doc "Applies a recorded model only when the current connection identity matches."
  @spec bind_configuration(t(), Configuration.t()) ::
          {:ok, Configuration.t()} | {:error, Draught.Error.Normalized.t()}
  def bind_configuration(%__MODULE__{} = binding, %Configuration{} = configuration) do
    current =
      {
        configuration.profile,
        Atom.to_string(configuration.provider),
        ConnectionIdentity.fingerprint(configuration)
      }

    recorded = {binding.profile, binding.provider, binding.connection}
    bind_model(current == recorded, binding, configuration)
  end

  @doc "Verifies the exact selected model and adapter after provider construction."
  @spec verify(t(), Preparation.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def verify(%__MODULE__{version: 1} = binding, %Preparation{} = preparation) do
    current = {adapter(preparation), preparation.request.model}
    expected = {binding.adapter, binding.model}

    verify_result(current == expected)
  end

  def verify(%__MODULE__{version: 2} = binding, %Preparation{} = preparation) do
    current = {
      adapter(preparation),
      preparation.request.model,
      CapabilityIdentity.fingerprint(
        preparation.capabilities,
        preparation.runner.tool_context.web
      )
    }

    expected = {binding.adapter, binding.model, binding.capabilities}

    verify_result(current == expected)
  end

  @doc "Encodes a binding as one versioned JSON object."
  @spec encode(t()) :: {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(%__MODULE__{version: 2} = binding) do
    binding
    |> valid_v2?()
    |> encode_result(binding)
  end

  def encode(%__MODULE__{}) do
    {:error, Failure.invalid_binding()}
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
           "capabilities" => capabilities,
           "connection" => connection,
           "model" => model,
           "profile" => profile,
           "provider" => provider,
           "schema" => @schema
         } = value
       )
       when map_size(value) == 7 and is_binary(adapter) and is_binary(capabilities) and
              is_binary(connection) and
              is_binary(model) and is_binary(profile) and is_binary(provider) do
    valid =
      Enum.all?([adapter, model, profile, provider], &(byte_size(&1) > 0)) and
        fingerprint?(capabilities) and fingerprint?(connection)

    decode_result(valid, adapter, capabilities, connection, model, profile, provider, 2)
  end

  defp decode_value(
         %{
           "adapter" => adapter,
           "connection" => connection,
           "model" => model,
           "profile" => profile,
           "provider" => provider,
           "schema" => @legacy_schema
         } = value
       )
       when map_size(value) == 6 and is_binary(adapter) and is_binary(connection) and
              is_binary(model) and is_binary(profile) and is_binary(provider) do
    valid =
      Enum.all?([adapter, model, profile, provider], &(byte_size(&1) > 0)) and
        fingerprint?(connection)

    decode_result(valid, adapter, nil, connection, model, profile, provider, 1)
  end

  defp decode_value(_value) do
    {:error, Failure.invalid_binding()}
  end

  defp decode_result(true, adapter, capabilities, connection, model, profile, provider, version) do
    {:ok,
     %__MODULE__{
       adapter: adapter,
       capabilities: capabilities,
       connection: connection,
       model: model,
       profile: profile,
       provider: provider,
       version: version
     }}
  end

  defp decode_result(
         false,
         _adapter,
         _capabilities,
         _connection,
         _model,
         _profile,
         _provider,
         _version
       ) do
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

  defp valid_v2?(binding) do
    Enum.all?(
      [binding.adapter, binding.model, binding.profile, binding.provider],
      &(is_binary(&1) and byte_size(&1) > 0)
    ) and fingerprint?(binding.capabilities) and fingerprint?(binding.connection)
  end

  defp encode_result(true, binding) do
    encode_value(binding)
  end

  defp encode_result(false, _binding) do
    {:error, Failure.invalid_binding()}
  end

  defp encode_value(binding) do
    value = %{
      "adapter" => binding.adapter,
      "capabilities" => binding.capabilities,
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

  defp fingerprint?(value) when is_binary(value) do
    byte_size(value) == 64 and String.match?(value, ~r/\A[0-9a-f]{64}\z/)
  end

  defp fingerprint?(_value) do
    false
  end
end
