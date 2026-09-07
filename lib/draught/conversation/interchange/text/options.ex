defmodule Draught.Conversation.Interchange.Text.Options do
  @moduledoc false

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @retained_fields [
    :attachment_content,
    :attachments,
    :metadata,
    :reasoning,
    :tool_arguments,
    :tool_results
  ]

  @enforce_keys [:retain]
  defstruct [:retain]

  @type retained_field ::
          :attachment_content
          | :attachments
          | :metadata
          | :reasoning
          | :tool_arguments
          | :tool_results
  @type t :: %__MODULE__{retain: MapSet.t(retained_field())}

  @doc "Validates text export options."
  @spec new(term()) :: Error.result(t())
  def new(options) do
    with {:ok, normalized} <- Attributes.normalize(options, [:retain]),
         {:ok, retain} <- retain(Map.get(normalized, :retain, [])) do
      {:ok, %__MODULE__{retain: MapSet.new(retain)}}
    end
  end

  @doc "Reports whether an optional sensitive field should be retained."
  @spec retained?(t(), retained_field()) :: boolean()
  def retained?(%__MODULE__{retain: retain}, field) do
    MapSet.member?(retain, field)
  end

  defp retain(fields) when is_list(fields) do
    fields
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &retain_field/2)
    |> reverse_fields()
  end

  defp retain(_fields) do
    Error.single([:retain], :invalid_type, "must be a list")
  end

  defp retain_field({field, _index}, {:ok, fields}) when field in @retained_fields do
    {:cont, {:ok, [field | fields]}}
  end

  defp retain_field({_field, index}, {:ok, _fields}) do
    result =
      Error.single(
        [:retain, index],
        :invalid_value,
        "is not a supported retained field"
      )

    {:halt, result}
  end

  defp reverse_fields({:ok, fields}) do
    {:ok, Enum.reverse(fields)}
  end

  defp reverse_fields({:error, %Error{}} = result) do
    result
  end
end
