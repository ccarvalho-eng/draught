defmodule Draught.Session.Journal.Codec.Error do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Encodes a normalized error into string-keyed data."
  @spec encode(Normalized.t()) :: map()
  def encode(%Normalized{} = error) do
    %{
      "code" => error.code,
      "hint" => error.hint,
      "kind" => Atom.to_string(error.kind),
      "message" => error.message,
      "retryable" => error.retryable
    }
  end

  @doc "Decodes string-keyed data through the canonical error constructor."
  @spec decode(term()) :: {:ok, Normalized.t()} | :error
  def decode(data) when is_map(data) do
    data
    |> Normalized.new()
    |> result()
  end

  def decode(_data) do
    :error
  end

  defp result({:ok, error}) do
    {:ok, error}
  end

  defp result({:error, _error}) do
    :error
  end
end
