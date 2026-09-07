defmodule Draught.CLI.Command.Error do
  @moduledoc """
  A bounded, closed command parsing failure suitable for terminal rendering.
  """

  @codes [
    :argument_too_large,
    :conflicting_options,
    :duplicate_option,
    :invalid_argument,
    :invalid_option,
    :invalid_option_value,
    :prompt_too_large,
    :too_many_arguments,
    :unexpected_argument,
    :unknown_option
  ]

  @enforce_keys [:code, :message]
  defstruct [:code, :message]

  @type code ::
          :argument_too_large
          | :conflicting_options
          | :duplicate_option
          | :invalid_argument
          | :invalid_option
          | :invalid_option_value
          | :prompt_too_large
          | :too_many_arguments
          | :unexpected_argument
          | :unknown_option

  @type t :: %__MODULE__{code: code(), message: String.t()}

  @doc "Builds a command error from an internal closed code and safe message."
  @spec new(code(), String.t()) :: t()
  def new(code, message) when code in @codes and is_binary(message) do
    %__MODULE__{code: code, message: message}
  end
end
