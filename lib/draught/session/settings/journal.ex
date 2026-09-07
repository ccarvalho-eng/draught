defmodule Draught.Session.Settings.Journal do
  @moduledoc false

  alias Draught.Session.Journal.Local
  alias Draught.Session.Journal.Local.Configuration

  @type setting :: Draught.Session.Journal.adapter() | nil

  @doc "Builds the disabled, custom, or default local journal setting."
  @spec build(map(), String.t(), String.t()) ::
          {:ok, setting()} | {:error, Draught.Validation.Error.t()}
  def build(%{journal: false}, _workspace, _id) do
    {:ok, nil}
  end

  def build(%{journal: {module, _configuration} = adapter}, _workspace, _id)
      when is_atom(module) do
    {:ok, adapter}
  end

  def build(attributes, workspace, id) do
    options = Map.get(attributes, :journal, [])

    with {:ok, configuration} <- Configuration.new(workspace, id, options) do
      {:ok, {Local, configuration}}
    end
  end
end
