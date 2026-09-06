defmodule Draught.Provider.OpenAI.Configuration.Builder do
  @moduledoc """
  Coordinates construction of validated OpenAI-compatible configuration.
  """

  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Configuration.Connection
  alias Draught.Provider.OpenAI.Configuration.Policies
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @keys [:base_url, :model, :credential, :headers, :timeouts, :retry, :reasoning_field]

  @doc "Builds configuration from its independently validated groups."
  @spec new(map() | keyword()) :: Error.result(Configuration.t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, @keys),
         {:ok, connection} <- Connection.new(normalized),
         {:ok, policies} <- Policies.new(normalized) do
      build(connection, policies)
    end
  end

  defp build(
         {base_url, model, credential, headers},
         {timeouts, retry, reasoning_field}
       ) do
    {:ok,
     %Configuration{
       base_url: base_url,
       model: model,
       credential: credential,
       headers: headers,
       timeouts: timeouts,
       retry: retry,
       reasoning_field: reasoning_field
     }}
  end
end
