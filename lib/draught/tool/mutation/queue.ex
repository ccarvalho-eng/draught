defmodule Draught.Tool.Mutation.Queue do
  @moduledoc """
  Serializes approved filesystem mutation operations.
  """

  use GenServer

  alias Draught.Error.Normalized

  @type result :: {:ok, String.t()} | {:error, Normalized.t()}

  @doc "Starts the mutation queue."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(options, :name, __MODULE__))
  end

  @doc "Runs one operation after all previously accepted mutations finish."
  @spec run(module(), term()) :: result()
  def run(module, input) when is_atom(module) do
    GenServer.call(__MODULE__, {:run, module, input}, :infinity)
  end

  @impl GenServer
  def init(:ok) do
    {:ok, :ready}
  end

  @impl GenServer
  def handle_call({:run, module, input}, {caller, _tag}, :ready) do
    caller
    |> Process.alive?()
    |> execute(module, input)
  end

  defp execute(true, module, input) do
    {:reply, module.run(input), :ready}
  end

  defp execute(false, _module, _input) do
    {:noreply, :ready}
  end
end
