defmodule Draught.Tool.Builtin.ReadFile.Reader do
  @moduledoc """
  Reads UTF-8 file content without retaining data beyond a byte limit.

  It reads at most one byte past the boundary so callers can distinguish an
  oversized file from valid content while treating encoding and I/O errors as
  unreadable input.
  """

  @type result :: {:ok, String.t()} | {:error, :too_large | :unreadable}

  @doc "Reads at most one byte beyond the supplied limit."
  @spec read(String.t(), pos_integer()) :: result()
  def read(path, maximum_bytes) do
    case File.open(path, [:read, :binary]) do
      {:ok, device} -> read_open(device, maximum_bytes)
      {:error, _reason} -> {:error, :unreadable}
    end
  end

  defp read_open(device, maximum_bytes) do
    device
    |> IO.binread(maximum_bytes + 1)
    |> normalize(maximum_bytes)
  after
    File.close(device)
  end

  defp normalize(:eof, _maximum_bytes) do
    {:ok, ""}
  end

  defp normalize(content, maximum_bytes) when is_binary(content) do
    with true <- byte_size(content) <= maximum_bytes,
         true <- String.valid?(content) do
      {:ok, content}
    else
      false -> size_or_encoding(content, maximum_bytes)
    end
  end

  defp normalize({:error, _reason}, _maximum_bytes) do
    {:error, :unreadable}
  end

  defp size_or_encoding(content, maximum_bytes) do
    content
    |> byte_size()
    |> then(&(&1 > maximum_bytes))
    |> size_result()
  end

  defp size_result(true) do
    {:error, :too_large}
  end

  defp size_result(false) do
    {:error, :unreadable}
  end
end
