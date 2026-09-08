defmodule Draught.CLI.Task.Approval.Prompt.Pending do
  @moduledoc """
  Holds the ephemeral identity and lifetime of one displayed approval request.
  """

  @enforce_keys [:requester, :reference, :deadline, :input, :monitor]
  defstruct [:requester, :reference, :deadline, :input, :monitor]

  @type t :: %__MODULE__{
          requester: pid(),
          reference: reference(),
          deadline: integer(),
          input: reference(),
          monitor: reference()
        }

  @doc "Monitors the requester and binds its decision to one input record and deadline."
  @spec new(pid(), reference(), integer(), reference()) :: t()
  def new(requester, reference, deadline, input) do
    %__MODULE__{
      requester: requester,
      reference: reference,
      deadline: deadline,
      input: input,
      monitor: Process.monitor(requester)
    }
  end

  @doc "Checks that an approval is still timely and its execution process still exists."
  @spec live?(t()) :: boolean()
  def live?(%__MODULE__{} = pending) do
    System.monotonic_time(:millisecond) < pending.deadline and
      Process.alive?(pending.requester)
  end
end
