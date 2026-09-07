defmodule Draught.Tool.Builtin.RunCommand.Subprocess.State do
  @moduledoc false

  alias Draught.Tool.Builtin.RunCommand.Execution

  @enforce_keys [:bytes, :execution, :output, :owner, :owner_monitor, :port, :reference, :timer]
  defstruct [:bytes, :execution, :output, :owner, :owner_monitor, :port, :reference, :timer]

  @type t :: %__MODULE__{
          bytes: non_neg_integer(),
          execution: Execution.t(),
          output: [binary()],
          owner: pid(),
          owner_monitor: reference(),
          port: port(),
          reference: reference(),
          timer: reference()
        }
end
