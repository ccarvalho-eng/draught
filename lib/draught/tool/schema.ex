defmodule Draught.Tool.Schema do
  @moduledoc """
  Validates the JSON Schema subset accepted for tool parameters.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.JSON

  @types ["object", "array", "string", "integer", "number", "boolean", "null"]

  @doc "Validates an object-rooted parameter schema."
  @spec validate(term(), [term()]) :: Error.result(map())
  def validate(schema, path \\ [:input_schema]) do
    with :ok <- JSON.validate_object(schema, path),
         :ok <- root_type(schema, path),
         :ok <- node(schema, path) do
      {:ok, schema}
    end
  end

  defp root_type(%{"type" => "object"}, _path) do
    :ok
  end

  defp root_type(_schema, path) do
    path_error(path, "type", :invalid_value, "must be object")
  end

  defp node(%{"type" => type} = schema, path) when type in @types do
    type_constraints(type, schema, path)
  end

  defp node(_schema, path) do
    path_error(path, "type", :invalid_value, "must be a supported JSON type")
  end

  defp type_constraints("object", schema, path) do
    with {:ok, properties} <- properties(schema, path),
         :ok <- required(schema, properties, path) do
      additional_properties(schema, path)
    end
  end

  defp type_constraints("array", schema, path) do
    case Map.fetch(schema, "items") do
      {:ok, items} when is_map(items) -> child_node(items, path, "items")
      _result -> path_error(path, "items", :required, "must be a schema object")
    end
  end

  defp type_constraints(_type, _schema, _path) do
    :ok
  end

  defp properties(schema, path) do
    case Map.get(schema, "properties", %{}) do
      properties when is_map(properties) -> validate_properties(properties, path)
      _properties -> path_error(path, "properties", :invalid_type, "must be an object")
    end
  end

  defp validate_properties(properties, path) do
    Enum.reduce_while(properties, {:ok, properties}, fn {name, property}, result ->
      property_path =
        path
        |> child("properties")
        |> child(name)

      case node(property, property_path) do
        :ok -> {:cont, result}
        {:error, %Error{}} = error -> {:halt, error}
      end
    end)
  end

  defp required(schema, properties, path) do
    case Map.get(schema, "required", []) do
      required when is_list(required) -> validate_required(required, properties, path)
      _required -> path_error(path, "required", :invalid_type, "must be a list")
    end
  end

  defp validate_required(required, properties, path) do
    names = Map.keys(properties)

    valid =
      Enum.all?(required, &(&1 in names)) and length(Enum.uniq(required)) == length(required)

    required_result(valid, path)
  end

  defp required_result(true, _path) do
    :ok
  end

  defp required_result(false, path) do
    path_error(
      path,
      "required",
      :invalid_value,
      "must contain unique property names declared by properties"
    )
  end

  defp additional_properties(schema, path) do
    case Map.get(schema, "additionalProperties", true) do
      value when is_boolean(value) ->
        :ok

      value when is_map(value) ->
        child_node(value, path, "additionalProperties")

      _value ->
        path_error(
          path,
          "additionalProperties",
          :invalid_type,
          "must be boolean or schema"
        )
    end
  end

  defp child(path, segment) do
    path
    |> Enum.reverse()
    |> then(&[segment | &1])
    |> Enum.reverse()
  end

  defp child_node(schema, path, segment) do
    path
    |> child(segment)
    |> then(&node(schema, &1))
  end

  defp path_error(path, segment, code, message) do
    path
    |> child(segment)
    |> Error.single(code, message)
  end
end
