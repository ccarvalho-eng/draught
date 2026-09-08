defmodule Draught.CLI.Interactive.Terminal.Input.Read do
  @moduledoc """
  Holds one terminal request's correlation and process-monitor ownership.

  Abandonment retains the device monitor and request identity but removes the
  recipient, preventing late input from escaping into another interaction.
  """

  alias Draught.CLI.Interactive.Terminal.Adapter

  @enforce_keys [:device, :device_monitor, :owner, :owner_monitor, :reference]
  defstruct [:device, :device_monitor, :owner, :owner_monitor, :reference]

  @type t :: %__MODULE__{
          device: pid(),
          device_monitor: reference(),
          owner: pid() | nil,
          owner_monitor: reference() | nil,
          reference: reference()
        }

  @doc "Attaches process monitors to one freshly allocated request identity."
  @spec new(pid(), pid(), reference()) :: t()
  def new(device, owner, reference) do
    %__MODULE__{
      device: device,
      device_monitor: Process.monitor(device),
      owner: owner,
      owner_monitor: Process.monitor(owner),
      reference: reference
    }
  end

  @doc "Revokes the recipient while retaining the invalidated device ownership."
  @spec abandon(t()) :: t()
  def abandon(read) do
    demonitor(read.owner_monitor)
    %{read | owner: nil, owner_monitor: nil}
  end

  @doc "Removes monitors after a completed request or a dead device."
  @spec release(t()) :: :ok
  def release(read) do
    demonitor(read.owner_monitor)
    demonitor(read.device_monitor)
  end

  @doc "Reports device failure only while a live interaction still owns the read."
  @spec unavailable(t()) :: :ok
  def unavailable(%__MODULE__{owner: owner} = read) when is_pid(owner) do
    send(owner, {:draught_terminal_input, read.reference, {:error, :io}})
    :ok
  end

  def unavailable(%__MODULE__{}) do
    :ok
  end

  @doc "Normalizes standard I/O replies without reflecting invalid payloads."
  @spec result(term()) :: Adapter.input_result()
  def result(data) when is_binary(data) do
    {:ok, data}
  end

  def result(data) when is_list(data) do
    data
    |> :unicode.characters_to_binary()
    |> text_result()
  rescue
    ArgumentError -> {:error, :io}
  end

  def result(:eof) do
    :eof
  end

  def result({:error, :interrupted}) do
    :interrupted
  end

  def result(_result) do
    {:error, :io}
  end

  defp text_result(data) when is_binary(data) do
    {:ok, data}
  end

  defp text_result(_data) do
    {:error, :io}
  end

  defp demonitor(nil) do
    :ok
  end

  defp demonitor(monitor) do
    Process.demonitor(monitor, [:flush])
    :ok
  end
end
