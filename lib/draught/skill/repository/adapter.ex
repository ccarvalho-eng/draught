defmodule Draught.Skill.Repository.Adapter do
  @moduledoc """
  Defines the effect boundary for skill discovery and instruction loading.
  """

  alias Draught.Skill.Catalog
  alias Draught.Skill.Definition

  @type configuration :: term()
  @type environment :: %{optional(String.t()) => String.t()}

  @doc "Lists bounded metadata without returning instruction bodies."
  @callback list(String.t(), environment(), configuration()) ::
              {:ok, Catalog.t()} | {:error, atom()}

  @doc "Loads one explicitly selected skill through the same precedence rules."
  @callback fetch(String.t(), String.t(), environment(), configuration()) ::
              {:ok, Definition.t()} | {:error, atom()}
end
