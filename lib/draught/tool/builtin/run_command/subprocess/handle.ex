defmodule Draught.Tool.Builtin.RunCommand.Subprocess.Handle do
  @moduledoc """
  An opaque reference to one running command subprocess.
  """

  @enforce_keys [:monitor, :pid, :reference]
  defstruct [:monitor, :pid, :reference]

  @type t :: %__MODULE__{monitor: reference(), pid: pid(), reference: reference()}
end
