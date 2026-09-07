defmodule Draught.Web.Fetch.Transport.ResponseHandler do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Web.Failure
  alias Draught.Web.Fetch.Response
  alias Draught.Web.Fetch.Transport.RawResponse
  alias Draught.Web.Policy
  alias Draught.Web.Source
  alias Draught.Web.Target

  @redirect_statuses [301, 302, 303, 307, 308]

  @doc """
  Validates a raw response and returns either a final response or a guarded redirect.
  """
  @spec handle(RawResponse.t(), Target.t(), Policy.t(), [String.t()]) ::
          {:ok, Response.t()}
          | {:redirect, Target.t(), String.t()}
          | {:error, Normalized.t()}
  def handle(%RawResponse{status: status} = response, target, policy, redirects)
      when status in @redirect_statuses do
    redirect(response, target, policy, redirects)
  end

  def handle(%RawResponse{status: status} = response, target, policy, redirects)
      when status in 200..299 do
    final(response, target, policy, redirects)
  end

  def handle(_response, _target, _policy, _redirects) do
    {:error, Failure.request_failed()}
  end

  defp redirect(response, target, policy, redirects) do
    with true <- Enum.count_until(redirects, policy.max_redirects) < policy.max_redirects,
         {:ok, location} <- location(response),
         {:ok, next} <- redirect_target(target, location),
         :ok <- no_downgrade(target, next),
         {:ok, source} <- Source.sanitize(target.logical_url) do
      {:redirect, next, source}
    else
      _result -> {:error, Failure.redirect_rejected()}
    end
  end

  defp location(response) do
    case RawResponse.header(response, "location") do
      [location] when byte_size(location) in 1..2_048 -> {:ok, location}
      _values -> {:error, :invalid_location}
    end
  end

  defp redirect_target(target, location) do
    with {:ok, relative} <- URI.new(location) do
      target.logical_url
      |> URI.merge(relative)
      |> URI.to_string()
      |> Target.new()
    end
  end

  defp no_downgrade(%Target{scheme: :https}, %Target{scheme: :http}) do
    {:error, :downgrade}
  end

  defp no_downgrade(_target, _next) do
    :ok
  end

  defp final(response, target, policy, redirects) do
    with :ok <- identity_encoding(response),
         {:ok, content_type} <- content_type(response),
         :ok <- content_size(response.body, policy.max_response_bytes),
         {:ok, final_url} <- Source.sanitize(target.logical_url) do
      canonical_response(response, policy, content_type, final_url, redirects)
    end
  end

  defp canonical_response(response, policy, content_type, final_url, redirects) do
    result =
      Response.new(
        [
          content: response.body,
          content_type: content_type,
          final_url: final_url,
          redirects: Enum.reverse(redirects)
        ],
        policy
      )

    case result do
      {:ok, canonical} -> {:ok, canonical}
      {:error, _error} -> {:error, Failure.content_invalid()}
    end
  end

  defp identity_encoding(response) do
    case RawResponse.header(response, "content-encoding") do
      [] -> :ok
      [value] -> identity_value(value)
      _values -> {:error, Failure.content_encoding_rejected()}
    end
  end

  defp identity_value(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> identity_result()
  end

  defp identity_result("identity") do
    :ok
  end

  defp identity_result(_value) do
    {:error, Failure.content_encoding_rejected()}
  end

  defp content_type(response) do
    case RawResponse.header(response, "content-type") do
      [value] -> validate_content_type(value)
      _values -> {:error, Failure.content_type_rejected()}
    end
  end

  defp validate_content_type(value) do
    case Response.validate_content_type(value) do
      {:ok, content_type} -> {:ok, content_type}
      {:error, _error} -> {:error, Failure.content_type_rejected()}
    end
  end

  defp content_size(content, maximum) when byte_size(content) <= maximum do
    :ok
  end

  defp content_size(_content, _maximum) do
    {:error, Failure.response_too_large()}
  end
end
