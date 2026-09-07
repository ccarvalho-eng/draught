defmodule Draught.CLI.Writer do
  @moduledoc """
  Emits one complete CLI result through the configured system adapter and returns its exit status.
  """

  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Dependencies

  @doc "Writes one complete record and maps the outcome to a stable process status."
  @spec emit(
          {:ok, iodata()} | {:error, :encoding},
          :stdout | :stderr,
          ExitStatus.category(),
          Dependencies.t()
        ) :: non_neg_integer()
  def emit(
        {:ok, content},
        stream,
        category,
        %Dependencies{system: {system, configuration}}
      ) do
    case system.write(stream, content, configuration) do
      :ok -> ExitStatus.value(category)
      {:error, _reason} -> ExitStatus.value(:internal)
    end
  end

  def emit({:error, :encoding}, _stream, _category, _dependencies) do
    ExitStatus.value(:internal)
  end
end
