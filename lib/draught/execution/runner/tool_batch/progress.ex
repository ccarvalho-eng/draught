defmodule Draught.Execution.Runner.ToolBatch.Progress do
  @moduledoc """
  Refreshes read-batch history after successful potentially mutating tools.

  Successful registered write and execute tools can invalidate earlier reads.
  Only all-read batches are forgotten. Mutation and unknown-tool batches remain
  guarded, and failed results alone never refresh history. Success indicates a
  possible state change, not proof of one; iteration and timeout limits remain
  necessary to bound alternating operations that make no useful progress.
  """

  alias Draught.Conversation.Message.Tool
  alias Draught.Execution.Runner.ToolBatch
  alias Draught.Tool.Definition
  alias Draught.Tool.Registry
  alias Draught.Tool.Result

  @doc "Refreshes read history from reconciled results and trusted registry risks."
  @spec refresh(MapSet.t(ToolBatch.key()), [Tool.t()], Registry.t() | nil) ::
          MapSet.t(ToolBatch.key())
  def refresh(seen, _messages, nil) do
    seen
  end

  def refresh(seen, messages, %Registry{} = registry) do
    changed = Enum.any?(messages, &successful_mutation?(&1, registry))
    refresh_reads(seen, registry, changed)
  end

  defp successful_mutation?(%Tool{result: %Result{status: :success, name: name}}, registry) do
    risk?(registry, name, [:write, :execute])
  end

  defp successful_mutation?(%Tool{}, _registry) do
    false
  end

  defp refresh_reads(seen, registry, true) do
    seen
    |> Enum.reject(&read_batch?(&1, registry))
    |> MapSet.new()
  end

  defp refresh_reads(seen, _registry, false) do
    seen
  end

  defp read_batch?(key, registry) do
    Enum.all?(key, fn {name, _arguments} -> risk?(registry, name, [:read]) end)
  end

  defp risk?(registry, name, risks) do
    case Registry.fetch(registry, name) do
      {:ok, %Definition{risk: risk}} -> risk in risks
      {:error, _error} -> false
    end
  end
end
