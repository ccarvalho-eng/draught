defmodule Draught.CLI.Task.Named.Create.Initialization do
  @moduledoc """
  Publishes the initial binding and optional display name under a create lease.

  Both records are established before provider execution. A confirmed failure
  remains abortable by the caller while publication uncertainty fails closed.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Catalog.Metadata
  alias Draught.CLI.Session.Store.Handle
  alias Draught.CLI.Task.Named.Input
  alias Draught.CLI.Task.Preparation

  @doc "Publishes the records required before a fresh named turn can execute."
  @spec persist(Input.t(), Preparation.t(), Handle.t()) ::
          :ok | {:error, Draught.CLI.Task.error()}
  def persist(%Input{} = input, %Preparation{} = preparation, %Handle{} = store) do
    binding = Binding.new(input.configuration, preparation)

    with :ok <- Binding.Local.create(store.paths, binding) do
      persist_session_label(input, store)
    end
  end

  defp persist_session_label(%Input{session_label: nil}, %Handle{}) do
    :ok
  end

  defp persist_session_label(
         %Input{identifier: identifier, session_label: label},
         %Handle{} = store
       ) do
    identifier
    |> Metadata.legacy()
    |> Metadata.rename(label)
    |> persist_metadata(store)
  end

  defp persist_metadata({:ok, metadata}, store) do
    Metadata.Local.put(store.paths, metadata)
  end

  defp persist_metadata({:error, _error} = error, _store) do
    error
  end
end
