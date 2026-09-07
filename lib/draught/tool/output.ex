defmodule Draught.Tool.Output do
  @moduledoc """
  Canonical content and optional provenance returned by a tool executor.
  """

  alias Draught.Tool.Result.Provenance
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:content]
  defstruct [:content, :provenance]

  @type t :: %__MODULE__{content: String.t(), provenance: Provenance.t() | nil}

  @doc "Builds a canonical executor output."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:content, :provenance]),
         {:ok, content} <- content(normalized),
         {:ok, provenance} <- provenance(normalized) do
      {:ok, %__MODULE__{content: content, provenance: provenance}}
    end
  end

  defp content(attributes) do
    with {:ok, content} <- Attributes.fetch_required(attributes, :content) do
      Value.string(content, [:content], allow_empty: true)
    end
  end

  defp provenance(%{provenance: %Provenance{} = provenance}) do
    provenance
    |> Map.from_struct()
    |> Provenance.new()
  end

  defp provenance(%{provenance: nil}) do
    {:ok, nil}
  end

  defp provenance(%{provenance: provenance}) when is_map(provenance) or is_list(provenance) do
    Provenance.new(provenance)
  end

  defp provenance(%{provenance: _provenance}) do
    Error.single([:provenance], :invalid_type, "must be canonical provenance")
  end

  defp provenance(_attributes) do
    {:ok, nil}
  end
end
