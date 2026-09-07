defmodule Draught.CLI.Task.Stream.Output do
  @moduledoc """
  Renders and writes one bounded projected task event.
  """

  alias Draught.CLI.Task.Stream.Emitter
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.CLI.Task.Stream.Renderer.JSONL
  alias Draught.CLI.Task.Stream.Renderer.Text

  @maximum_terminal_bytes 65_536

  @type mode :: :bounded | :terminal
  @type result ::
          {:ok, State.t()} | {:error, :encoding | :output_limit | :write}

  @doc "Renders one projected event and writes it to its deterministic stream."
  @spec emit({module(), term()}, State.t(), Draught.CLI.Task.Stream.Event.t(), mode()) :: result()
  def emit(system, projector, event, mode) do
    with {:ok, rendered} <- render(projector.format, event),
         bytes = IO.iodata_length(rendered),
         :ok <- within_limit(projector, bytes, mode),
         :ok <- Emitter.write(system, output_stream(projector.format, event), rendered) do
      {:ok, record_bytes(projector, bytes, mode)}
    else
      {:error, :encoding} -> {:error, :encoding}
      {:error, :output_limit} -> {:error, :output_limit}
      {:error, _reason} -> {:error, :write}
    end
  end

  defp render(:text, event) do
    Text.render(event)
  end

  defp render(:jsonl, event) do
    JSONL.render(event)
  end

  defp within_limit(_projector, bytes, :terminal) do
    within_limit_result(bytes <= @maximum_terminal_bytes)
  end

  defp within_limit(projector, bytes, :bounded) do
    within_limit_result(projector.emitted_bytes + bytes <= projector.maximum_bytes)
  end

  defp within_limit_result(true) do
    :ok
  end

  defp within_limit_result(false) do
    {:error, :output_limit}
  end

  defp record_bytes(projector, _bytes, :terminal) do
    projector
  end

  defp record_bytes(projector, bytes, :bounded) do
    State.record_bytes(projector, bytes)
  end

  defp output_stream(:jsonl, _event) do
    :stdout
  end

  defp output_stream(:text, %{type: :failure}) do
    :stderr
  end

  defp output_stream(:text, _event) do
    :stdout
  end
end
