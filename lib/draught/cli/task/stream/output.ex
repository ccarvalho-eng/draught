defmodule Draught.CLI.Task.Stream.Output do
  @moduledoc """
  Renders and writes one bounded projected task event.
  """

  alias Draught.CLI.Task.Stream.Emitter
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.CLI.Task.Stream.Renderer.Interactive
  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown
  alias Draught.CLI.Task.Stream.Renderer.JSONL
  alias Draught.CLI.Task.Stream.Renderer.Text

  @maximum_terminal_bytes 65_536

  @type mode :: :bounded | :terminal
  @type renderer :: Markdown.State.t() | nil
  @type legacy_result :: {:ok, State.t()} | {:error, :encoding | :output_limit | :write}
  @type result ::
          {:ok, State.t(), renderer()} | {:error, :encoding | :output_limit | :write}

  @doc "Builds optional state for the selected stream renderer."
  @spec new_renderer(State.t()) :: renderer()
  def new_renderer(%State{format: :text, presentation: :interactive, styled: true}) do
    Markdown.new()
  end

  def new_renderer(%State{}) do
    nil
  end

  @doc "Renders one event without retaining optional interactive presentation state."
  @spec emit({module(), term()}, State.t(), Draught.CLI.Task.Stream.Event.t(), mode()) ::
          legacy_result()
  def emit(system, projector, event, mode) do
    case emit(system, projector, nil, event, mode) do
      {:ok, recorded, _renderer} -> {:ok, recorded}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Renders one event while retaining optional interactive presentation state."
  @spec emit(
          {module(), term()},
          State.t(),
          renderer(),
          Draught.CLI.Task.Stream.Event.t(),
          mode()
        ) :: result()
  def emit(system, projector, renderer, event, mode) do
    with {:ok, rendered, updated_renderer} <- render(projector, renderer, event),
         bytes = IO.iodata_length(rendered),
         :ok <- within_limit(projector, bytes, mode),
         :ok <- write(system, projector, event, rendered, bytes) do
      {:ok, record_bytes(projector, bytes, mode), updated_renderer}
    else
      {:error, :encoding} -> {:error, :encoding}
      {:error, :output_limit} -> {:error, :output_limit}
      {:error, _reason} -> {:error, :write}
    end
  end

  defp render(
         %State{format: :text, presentation: :interactive, styled: styled?},
         renderer,
         event
       ) do
    Interactive.render(event, styled?, renderer)
  end

  defp render(%State{format: :text}, renderer, event) do
    {:ok, rendered} = Text.render(event)
    {:ok, rendered, renderer}
  end

  defp render(%State{format: :jsonl}, renderer, event) do
    case JSONL.render(event) do
      {:ok, rendered} -> {:ok, rendered, renderer}
      {:error, :encoding} -> {:error, :encoding}
    end
  end

  defp write(_system, _projector, _event, _rendered, 0) do
    :ok
  end

  defp write(system, projector, event, rendered, _bytes) do
    Emitter.write(system, output_stream(projector.format, event), rendered)
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
