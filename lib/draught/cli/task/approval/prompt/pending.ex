defmodule Draught.CLI.Task.Approval.Prompt.Pending do
  @moduledoc """
  Holds the ephemeral identity of one displayed approval request.
  """

  @enforce_keys [:requester, :reference, :input, :monitor]
  defstruct [:requester, :reference, :input, :monitor]

  @type t :: %__MODULE__{
          requester: pid(),
          reference: reference(),
          input: reference(),
          monitor: reference() | nil
        }

  @doc "Monitors the requester and binds its decision to one input record."
  @spec new(pid(), reference(), reference()) :: t()
  def new(requester, reference, input) do
    %__MODULE__{
      requester: requester,
      reference: reference,
      input: input,
      monitor: Process.monitor(requester)
    }
  end

  @doc "Checks that an approval is still timely and its execution process still exists."
  @spec live?(t()) :: boolean()
  def live?(%__MODULE__{} = pending) do
    Process.alive?(pending.requester)
  end

  @doc "Stops monitoring a requester after its termination has been observed."
  @spec requester_stopped(t()) :: t()
  def requester_stopped(%__MODULE__{monitor: nil} = pending) do
    pending
  end

  def requester_stopped(%__MODULE__{monitor: monitor} = pending) do
    Process.demonitor(monitor, [:flush])
    %{pending | monitor: nil}
  end
end
