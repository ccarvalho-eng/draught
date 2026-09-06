defmodule Draught.Tool.Schema.Arguments do
  @moduledoc """
  Validates canonical call arguments against the supported schema subset.
  """

  alias Draught.Validation.Error

  @doc "Validates arguments against a previously validated tool schema."
  @spec validate(map(), map()) :: :ok | {:error, Error.t()}
  def validate(arguments, schema) do
    node(arguments, schema, [:arguments])
  end

  defp node(value, %{"type" => "object"} = schema, path) do
    object(value, schema, path)
  end

  defp node(value, %{"type" => "array"} = schema, path) do
    array(value, schema, path)
  end

  defp node(value, %{"type" => "string"}, path) do
    type_result(is_binary(value), path, "string")
  end

  defp node(value, %{"type" => "integer"}, path) do
    type_result(is_integer(value), path, "integer")
  end

  defp node(value, %{"type" => "number"}, path) do
    type_result(is_number(value), path, "number")
  end

  defp node(value, %{"type" => "boolean"}, path) do
    type_result(is_boolean(value), path, "boolean")
  end

  defp node(value, %{"type" => "null"}, path) do
    type_result(is_nil(value), path, "null")
  end

  defp object(value, schema, path) when is_map(value) do
    properties = Map.get(schema, "properties", %{})

    with :ok <- required(value, Map.get(schema, "required", []), path),
         :ok <- declared_properties(value, properties, path) do
      additional_properties(
        value,
        properties,
        Map.get(schema, "additionalProperties", true),
        path
      )
    end
  end

  defp object(_value, _schema, path) do
    type_error(path, "object")
  end

  defp array(value, %{"items" => item_schema}, path) when is_list(value) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {item, index}, :ok ->
      validation_step(node(item, item_schema, child(path, index)))
    end)
  end

  defp array(_value, _schema, path) do
    type_error(path, "array")
  end

  defp required(value, required, path) do
    required
    |> Enum.sort()
    |> Enum.find(&(not Map.has_key?(value, &1)))
    |> required_result(path)
  end

  defp required_result(nil, _path) do
    :ok
  end

  defp required_result(name, path) do
    path
    |> child(name)
    |> Error.single(:required, "is required")
  end

  defp declared_properties(value, properties, path) do
    properties
    |> Enum.sort_by(fn {name, _schema} -> name end)
    |> Enum.reduce_while(:ok, fn {name, schema}, :ok ->
      case Map.fetch(value, name) do
        {:ok, argument} -> validation_step(node(argument, schema, child(path, name)))
        :error -> {:cont, :ok}
      end
    end)
  end

  defp additional_properties(value, properties, policy, path) do
    value
    |> Map.drop(Map.keys(properties))
    |> Enum.sort_by(fn {name, _argument} -> name end)
    |> validate_additional(policy, path)
  end

  defp validate_additional([], _policy, _path) do
    :ok
  end

  defp validate_additional([{name, _argument} | _rest], false, path) do
    path
    |> child(name)
    |> Error.single(:unknown_key, "is not declared by the tool schema")
  end

  defp validate_additional(_additional, true, _path) do
    :ok
  end

  defp validate_additional(additional, schema, path) when is_map(schema) do
    Enum.reduce_while(additional, :ok, fn {name, argument}, :ok ->
      validation_step(node(argument, schema, child(path, name)))
    end)
  end

  defp type_result(true, _path, _expected) do
    :ok
  end

  defp type_result(false, path, expected) do
    type_error(path, expected)
  end

  defp type_error(path, expected) do
    Error.single(path, :invalid_type, "must be a JSON #{expected}")
  end

  defp validation_step(:ok) do
    {:cont, :ok}
  end

  defp validation_step({:error, %Error{}} = result) do
    {:halt, result}
  end

  defp child(path, segment) do
    path
    |> Enum.reverse()
    |> then(&[segment | &1])
    |> Enum.reverse()
  end
end
