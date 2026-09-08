defmodule Draught.CLI.Task.OneShot.Approval do
  @moduledoc """
  Coordinates terminal approval effects without blocking the session observer.

  The observer retains ownership of acknowledgements; this boundary only pauses
  presentation and advances the current prompt.
  """

  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Stream
  alias Draught.Error.Normalized

  @doc "Reports whether terminal input is still owned by an approval prompt."
  @spec pending?(Stream.t()) :: boolean()
  def pending?(%Stream{approval: %Prompt{pending: %Prompt.Pending{}}}) do
    true
  end

  def pending?(%Stream{}) do
    false
  end

  @doc "Returns whether a terminal outcome must wait for its outstanding input read."
  @spec retain_pending_input?(term(), Stream.t()) :: boolean()
  def retain_pending_input?(
        {:error, %Normalized{kind: :cancellation}},
        _stream
      ) do
    false
  end

  def retain_pending_input?(_outcome, stream) do
    pending?(stream)
  end

  @doc "Pauses activity before displaying an operation and requesting input."
  @spec request(Stream.t(), {pid(), reference(), Draught.Tool.Approval.Request.t()}) ::
          {:ok, Stream.t()} | {:error, Stream.t()}
  def request(stream, operation) do
    case Stream.pause(stream) do
      {:ok, paused} -> begin_prompt(paused, operation)
      {:error, :write, failed} -> {:error, failed}
    end
  end

  @doc "Delivers one matching terminal response and resumes the activity indicator."
  @spec reply(Stream.t(), Draught.CLI.Interactive.Terminal.Adapter.input_result()) ::
          {:ok, Stream.t()} | {:error, Stream.t()}
  def reply(stream, input) do
    case Prompt.reply(stream.approval, input) do
      {:ok, prompt} -> {:ok, Stream.start(%{stream | approval: prompt})}
      {:error, prompt} -> {:error, %{stream | approval: prompt}}
    end
  end

  @doc "Retains terminal input after observing that its requester stopped."
  @spec requester_stopped(Stream.t()) :: Stream.t()
  def requester_stopped(%Stream{approval: %Prompt{} = prompt} = stream) do
    %{stream | approval: Prompt.requester_stopped(prompt)}
  end

  @doc "Revokes unread approval input before returning a terminal task result."
  @spec close(Stream.t()) :: Stream.t()
  def close(stream) do
    %{stream | approval: Prompt.close(stream.approval)}
  end

  defp begin_prompt(stream, operation) do
    case Prompt.request(stream.approval, operation, stream.system) do
      {:ok, prompt} -> {:ok, %{stream | approval: prompt}}
      {:error, prompt} -> {:error, %{stream | approval: prompt}}
    end
  end
end
