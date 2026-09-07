defmodule Draught.Session.Journal do
  @moduledoc """
  Dispatches session persistence through an explicitly injected journal adapter.
  """

  alias Draught.Session.Journal.Event
  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Replay

  @type adapter :: {module(), term()}
  @type handle :: {module(), term()}
  @type error :: Draught.Error.Normalized.t() | Draught.Validation.Error.t()

  @doc "Opens a configured journal and returns its writer handle and replayed state."
  @spec open(adapter()) :: {:ok, handle(), Replay.t()} | {:error, error()}
  def open({module, configuration}) when is_atom(module) do
    with :ok <- validate(module) do
      case module.open(configuration) do
        {:ok, handle, %Replay{} = replay} -> {:ok, {module, handle}, replay}
        {:error, _error} = result -> result
        _result -> {:error, Failure.io()}
      end
    end
  end

  def open(_adapter) do
    {:error, Failure.io()}
  end

  @doc "Appends one canonical event through an opened writer handle."
  @spec append(handle(), Event.t()) ::
          {:ok, handle()} | {:error, error()}
  def append({module, handle}, event) do
    case module.append(handle, event) do
      {:ok, updated} -> {:ok, {module, updated}}
      {:error, _error} = result -> result
      _result -> {:error, Failure.io()}
    end
  end

  @doc "Writes one disposable checkpoint through an opened writer handle."
  @spec checkpoint(handle()) :: {:ok, handle()} | {:error, error()}
  def checkpoint({module, handle}) do
    case module.checkpoint(handle) do
      {:ok, updated} -> {:ok, {module, updated}}
      {:error, _error} = result -> result
      _result -> {:error, Failure.io()}
    end
  end

  @doc "Replays a configured journal without opening it for writes."
  @spec replay(adapter()) :: {:ok, Replay.t()} | {:error, error()}
  def replay({module, configuration}) when is_atom(module) do
    with :ok <- validate(module) do
      case module.replay(configuration) do
        {:ok, %Replay{} = replay} -> {:ok, replay}
        {:error, _error} = result -> result
        _result -> {:error, Failure.io()}
      end
    end
  end

  def replay(_adapter) do
    {:error, Failure.io()}
  end

  defp validate(module) do
    required = [open: 1, append: 2, checkpoint: 1, replay: 1]
    loaded = Code.ensure_loaded?(module)

    available =
      loaded and
        Enum.all?(required, fn {name, arity} ->
          function_exported?(module, name, arity)
        end)

    validate_result(available)
  end

  defp validate_result(true) do
    :ok
  end

  defp validate_result(false) do
    {:error, Failure.io()}
  end
end
