defmodule Draught.CLI.Session.Binding.ConnectionIdentity do
  @moduledoc """
  Derives an opaque identity for a resolved CLI provider connection.

  The digest binds named sessions to their endpoint and configured headers
  without writing raw connection values to session state. It is retained only
  in the owner-readable session directory and must not be exposed publicly.
  """

  alias Draught.CLI.Configuration

  @doc "Returns the lowercase SHA-256 identity of one resolved connection."
  @spec fingerprint(Configuration.t()) :: String.t()
  def fingerprint(%Configuration{} = configuration) do
    headers =
      configuration.headers
      |> Enum.sort()
      |> Enum.flat_map(fn {name, value} -> [name, value] end)

    [configuration.base_url | headers]
    |> Enum.map_join(&frame/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp frame(value) do
    size =
      value
      |> byte_size()
      |> Integer.to_string()

    [size, ":", value]
  end
end
