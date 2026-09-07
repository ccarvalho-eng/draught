defmodule Draught.Tool.Result.Provenance do
  @moduledoc """
  Bounded origin and trust metadata attached to a tool result.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value
  alias Draught.Web.Source

  @maximum_sources 20
  @maximum_source_bytes 2_048

  @enforce_keys [:origin, :trust, :sources]
  defstruct [:origin, :trust, :sources]

  @type t :: %__MODULE__{
          origin: :web,
          trust: :untrusted,
          sources: [String.t()]
        }

  @doc "Builds bounded provenance from a closed origin and trust classification."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:origin, :trust, :sources]),
         {:ok, origin} <- enum(normalized, :origin, [:web]),
         {:ok, trust} <- enum(normalized, :trust, [:untrusted]),
         {:ok, sources} <- sources(normalized) do
      {:ok, %__MODULE__{origin: origin, trust: trust, sources: sources}}
    end
  end

  defp enum(attributes, key, values) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      Value.enum(value, values, [key])
    end
  end

  defp sources(attributes) do
    with {:ok, values} <- Attributes.fetch_required(attributes, :sources),
         true <- is_list(values) and length(values) <= @maximum_sources,
         {:ok, canonical} <- normalize_sources(values),
         true <- Enum.uniq(canonical) == canonical do
      {:ok, canonical}
    else
      false -> Error.single([:sources], :invalid_value, "must contain unique bounded sources")
      {:error, %Error{}} = result -> result
    end
  end

  defp normalize_sources(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &normalize_source/2)
    |> reverse()
  end

  defp normalize_source({value, index}, {:ok, canonical}) do
    with {:ok, source} <- Source.sanitize(value, [:sources, index]),
         true <- byte_size(source) <= @maximum_source_bytes do
      {:cont, {:ok, [source | canonical]}}
    else
      false ->
        {:halt, Error.single([:sources, index], :too_large, "exceeds the maximum byte size")}

      {:error, %Error{}} = result ->
        {:halt, result}
    end
  end

  defp reverse({:ok, sources}) do
    {:ok, Enum.reverse(sources)}
  end

  defp reverse({:error, %Error{}} = result) do
    result
  end
end
