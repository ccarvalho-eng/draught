defmodule Draught.CLI.Task.OneShot.Approval do
  @moduledoc """
  Coordinates terminal approval effects without blocking the session observer.

  The observer retains ownership of session deadlines and acknowledgements;
  this boundary only pauses presentation and advances the current prompt.
  """

  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Stream

  @doc "Reports whether the current approval has reached its deadline."
  @spec expired?(Stream.t()) :: boolean()
  def expired?(stream) do
    Prompt.wait_timeout(stream.approval, 1) == 0
  end

  @doc "Pauses activity before displaying an operation and requesting input."
  @spec request(Stream.t(), {pid(), reference(), integer(), Draught.Tool.Approval.Request.t()}) ::
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
