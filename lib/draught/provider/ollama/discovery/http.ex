defmodule Draught.Provider.Ollama.Discovery.HTTP do
  @moduledoc """
  Defines the sanitized HTTP boundary for Ollama discovery.
  """

  alias Draught.Provider.Ollama.Discovery.Configuration
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Response

  @type method :: :get | :post
  @type body :: map() | nil

  @doc "Executes one bounded native discovery request."
  @callback request(method(), String.t(), body(), Configuration.t()) ::
              {:ok, Response.t()} | {:error, Failure.t()}
end
