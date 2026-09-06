defmodule Draught.Provider.OpenAI.Request.Tool do
  @moduledoc """
  Serializes canonical tool specifications.
  """

  alias Draught.Tool.Specification

  @doc "Encodes one function-tool declaration."
  @spec encode(Specification.t()) :: map()
  def encode(%Specification{} = specification) do
    %{
      "type" => "function",
      "function" => %{
        "name" => specification.name,
        "description" => specification.description,
        "parameters" => specification.input_schema
      }
    }
  end
end
