defmodule Draught.Tool.Name do
  @moduledoc """
  Validates provider-neutral tool names.
  """

  alias Draught.Validation.Error

  @pattern ~r/^[A-Za-z][A-Za-z0-9_-]{0,63}$/

  @doc "Validates a portable tool name at the supplied error path."
  @spec validate(term(), [term()]) :: Error.result(String.t())
  def validate(name, path \\ [:name]) do
    name
    |> portable?()
    |> result(name, path)
  end

  defp portable?(name) do
    is_binary(name) and Regex.match?(@pattern, name)
  end

  defp result(true, name, _path) do
    {:ok, name}
  end

  defp result(false, _name, path) do
    Error.single(path, :invalid_value, "must be a portable tool name")
  end
end
