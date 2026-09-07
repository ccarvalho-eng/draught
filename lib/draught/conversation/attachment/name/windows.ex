defmodule Draught.Conversation.Attachment.Name.Windows do
  @moduledoc """
  Rejects attachment names reserved by Windows filesystems.

  Validation is case-insensitive and applies to the basename before the first
  extension separator.
  """

  alias Draught.Validation.Error

  @reserved_basenames ~w(AUX COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 CON LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9 NUL PRN)

  @doc "Rejects leaf names whose basename is reserved on Windows."
  @spec validate(String.t(), [term()]) :: Error.result(String.t())
  def validate(name, path) do
    name
    |> String.split(".", parts: 2)
    |> List.first()
    |> String.upcase()
    |> reserved_result(name, path)
  end

  defp reserved_result(basename, _name, path) when basename in @reserved_basenames do
    Error.single(path, :invalid_value, "must not use a platform-reserved basename")
  end

  defp reserved_result(_basename, name, _path) do
    {:ok, name}
  end
end
