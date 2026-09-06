defmodule Draught.Validation.Violation do
  @moduledoc """
  Describes one deterministic violation found while constructing a value.
  """

  @enforce_keys [:path, :code, :message]
  defstruct [:path, :code, :message]

  @type path_segment :: atom() | String.t() | non_neg_integer()
  @type code ::
          :duplicate_key
          | :invalid_relationship
          | :invalid_type
          | :invalid_value
          | :required
          | :too_deep
          | :too_large
          | :unknown_key
  @type t :: %__MODULE__{
          path: [path_segment()],
          code: code(),
          message: String.t()
        }

  @doc "Builds a violation from trusted validation metadata."
  @spec new([path_segment()], code(), String.t()) :: t()
  def new(path, code, message) do
    %__MODULE__{path: path, code: code, message: message}
  end
end
