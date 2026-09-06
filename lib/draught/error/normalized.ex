defmodule Draught.Error.Normalized do
  @moduledoc """
  A normalized, safe failure produced while attempting Draught work.

  It intentionally excludes raw exceptions, payloads, headers, credentials,
  stack traces, and arbitrary metadata.
  """

  alias Draught.Validation
  alias Draught.Validation.Attributes
  alias Draught.Validation.Value

  @kinds [
    :cancellation,
    :capability,
    :configuration,
    :policy,
    :protocol,
    :timeout,
    :tool,
    :transport
  ]

  @enforce_keys [:kind, :code, :message, :retryable]
  defstruct [:kind, :code, :message, :hint, :retryable]

  @type kind ::
          :cancellation
          | :capability
          | :configuration
          | :policy
          | :protocol
          | :timeout
          | :tool
          | :transport
  @type code :: String.t()
  @type t :: %__MODULE__{
          kind: kind(),
          code: code(),
          message: String.t(),
          hint: String.t() | nil,
          retryable: boolean()
        }

  @doc "Builds a normalized runtime error from external attributes."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:kind, :code, :message, :hint, :retryable]),
         {:ok, kind} <- required_kind(normalized),
         {:ok, code} <- required_code(normalized),
         {:ok, message} <- required_string(normalized, :message),
         {:ok, hint} <- optional_string(normalized, :hint),
         {:ok, retryable} <- retryable(normalized) do
      {:ok,
       %__MODULE__{
         kind: kind,
         code: code,
         message: message,
         hint: hint,
         retryable: retryable
       }}
    end
  end

  @doc "Builds a normalized runtime error from explicit fields."
  @spec new(kind(), code(), String.t(), keyword()) :: Validation.result(t())
  def new(kind, code, message, options \\ []) do
    options
    |> Keyword.merge(kind: kind, code: code, message: message)
    |> new()
  end

  @doc "Lists the closed set of normalized runtime error kinds."
  @spec kinds() :: [kind()]
  def kinds do
    @kinds
  end

  defp required_kind(attributes) do
    with {:ok, kind} <- Attributes.fetch_required(attributes, :kind) do
      normalize_kind(kind)
    end
  end

  defp normalize_kind(kind) when kind in @kinds do
    {:ok, kind}
  end

  defp normalize_kind(kind) when is_binary(kind) do
    case Enum.find(@kinds, &(Atom.to_string(&1) == kind)) do
      nil -> Validation.error([:kind], :invalid_value, "is not a supported error kind")
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_kind(_kind) do
    Validation.error([:kind], :invalid_value, "is not a supported error kind")
  end

  defp required_code(attributes) do
    with {:ok, code} <- Attributes.fetch_required(attributes, :code) do
      validate_code(code)
    end
  end

  defp validate_code(code) when is_atom(code) do
    code
    |> Atom.to_string()
    |> Value.string([:code])
  end

  defp validate_code(code) when is_binary(code) and byte_size(code) > 0 do
    Value.string(code, [:code])
  end

  defp validate_code(_code) do
    Validation.error([:code], :invalid_value, "must be a non-empty string or atom")
  end

  defp required_string(attributes, key) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      validate_string(value, key)
    end
  end

  defp optional_string(attributes, key) do
    case Map.get(attributes, key) do
      nil -> {:ok, nil}
      value -> validate_string(value, key)
    end
  end

  defp validate_string(value, key) when is_binary(value) and byte_size(value) > 0 do
    Value.string(value, [key])
  end

  defp validate_string(_value, key) do
    Validation.error([key], :invalid_value, "must be a non-empty string")
  end

  defp retryable(attributes) do
    case Map.get(attributes, :retryable, false) do
      value when is_boolean(value) -> {:ok, value}
      _value -> Validation.error([:retryable], :invalid_type, "must be a boolean")
    end
  end
end
