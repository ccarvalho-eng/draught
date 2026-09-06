defmodule Draught.Provider.OpenAI.Configuration.Connection do
  @moduledoc """
  Validates the endpoint, model, credential, and custom-header relationship.
  """

  alias Draught.Provider.OpenAI.Configuration.Credential
  alias Draught.Provider.OpenAI.Configuration.Endpoint
  alias Draught.Provider.OpenAI.Configuration.Headers
  alias Draught.Provider.OpenAI.Configuration.Model
  alias Draught.Validation.Error

  @type t :: {
          String.t(),
          String.t() | nil,
          Credential.t() | nil,
          %{optional(String.t()) => String.t()}
        }

  @doc "Builds the validated connection group."
  @spec new(map()) :: Error.result(t())
  def new(attributes) do
    with {:ok, base_url} <- endpoint(attributes),
         {:ok, model} <- model(attributes),
         {:ok, credential} <- credential(attributes),
         {:ok, headers} <- headers(attributes),
         :ok <- unique_authorization_source(credential, headers) do
      {:ok, {base_url, model, credential, headers}}
    end
  end

  defp endpoint(attributes) do
    attributes
    |> Map.get(:base_url)
    |> Endpoint.new()
  end

  defp model(attributes) do
    attributes
    |> Map.get(:model)
    |> Model.new()
  end

  defp credential(attributes) do
    attributes
    |> Map.get(:credential)
    |> normalize_credential()
  end

  defp normalize_credential(nil) do
    {:ok, nil}
  end

  defp normalize_credential(%Credential{} = credential) do
    credential
    |> Credential.value()
    |> Credential.new()
  end

  defp normalize_credential(value) do
    Credential.new(value)
  end

  defp headers(attributes) do
    attributes
    |> Map.get(:headers, %{})
    |> Headers.new()
  end

  defp unique_authorization_source(%Credential{}, %{"authorization" => _value}) do
    Error.single(
      [:headers],
      :invalid_relationship,
      "must not contain authorization when a credential is configured"
    )
  end

  defp unique_authorization_source(_credential, _headers) do
    :ok
  end
end
