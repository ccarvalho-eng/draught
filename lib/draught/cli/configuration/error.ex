defmodule Draught.CLI.Configuration.Error do
  @moduledoc """
  Describes a configuration failure without retaining rejected values.
  """

  alias Draught.CLI.Configuration.Source

  @enforce_keys [:source, :path, :code, :message]
  defstruct [:source, :path, :code, :message]

  @type code ::
          :authority_denied
          | :duplicate_key
          | :duplicate_source
          | :invalid_json
          | :invalid_type
          | :invalid_value
          | :missing_credential
          | :required
          | :source_unavailable
          | :too_deep
          | :too_large
          | :unknown_key
          | :unknown_profile
  @type path_segment :: atom() | non_neg_integer()
  @type t :: %__MODULE__{
          source: Source.kind(),
          path: [path_segment()],
          code: code(),
          message: String.t()
        }
  @type result(value) :: {:ok, value} | {:error, t()}

  @doc "Builds a tagged error from trusted diagnostic metadata."
  @spec new(Source.kind(), [path_segment()], code(), String.t()) :: {:error, t()}
  def new(source, path, code, message) do
    {:error, %__MODULE__{source: source, path: path, code: code, message: message}}
  end
end
