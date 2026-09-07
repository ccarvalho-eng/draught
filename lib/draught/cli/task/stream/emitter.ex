defmodule Draught.CLI.Task.Stream.Emitter do
  @moduledoc """
  Owns ordered writes from the task stream to the injected CLI system boundary.
  """

  alias Draught.CLI.System.Adapter

  @doc "Writes one complete projected fragment to the selected standard stream."
  @spec write({module(), term()}, Adapter.stream(), iodata()) ::
          :ok | {:error, :closed | :io}
  def write({system, configuration}, stream, content) do
    system.write(stream, content, configuration)
  end
end
