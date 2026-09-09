defmodule Draught.Filesystem.OpenFile do
  @moduledoc """
  Verifies that an opened regular file still has its expected filesystem identity.

  Callers can compare a prior `File.lstat/1` result with the descriptor opened
  for reading, closing the replacement window between validation and use.
  """

  @doc "Verifies an open descriptor against a previously captured regular-file stat."
  @spec verify(IO.device(), File.Stat.t()) :: :ok | {:error, :unsafe_file}
  def verify(file, %File.Stat{} = expected) do
    file
    |> :file.read_file_info()
    |> verify_result(expected)
  end

  defp verify_result({:ok, record}, expected) do
    record
    |> File.Stat.from_record()
    |> same_identity?(expected)
    |> identity_result()
  end

  defp verify_result(_result, _expected) do
    {:error, :unsafe_file}
  end

  defp same_identity?(
         %File.Stat{
           type: :regular,
           major_device: major_device,
           minor_device: minor_device,
           inode: inode
         },
         %File.Stat{
           type: :regular,
           major_device: major_device,
           minor_device: minor_device,
           inode: inode
         }
       ) do
    true
  end

  defp same_identity?(%File.Stat{}, %File.Stat{}) do
    false
  end

  defp identity_result(true) do
    :ok
  end

  defp identity_result(false) do
    {:error, :unsafe_file}
  end
end
