defmodule Draught.Tool.Builtin.RunCommand.Execution do
  @moduledoc """
  Validated operating-system process execution settings.
  """

  @enforce_keys [
    :arguments,
    :environment,
    :executable,
    :max_output_bytes,
    :timeout_ms,
    :workspace
  ]
  defstruct [
    :arguments,
    :environment,
    :executable,
    :max_output_bytes,
    :timeout_ms,
    :workspace
  ]

  @type t :: %__MODULE__{
          arguments: [String.t()],
          environment: [{charlist(), charlist() | false}],
          executable: String.t(),
          max_output_bytes: pos_integer(),
          timeout_ms: pos_integer(),
          workspace: String.t()
        }

  @doc "Builds process execution settings from validated internal values."
  @spec new(keyword()) :: t()
  def new(attributes) do
    struct!(__MODULE__, attributes)
  end
end
