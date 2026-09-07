defmodule Draught.Web.Fetch.Transport.Mint do
  @moduledoc """
  Guarded fetch adapter with manual redirects and address-pinned connections.
  """

  @behaviour Draught.Web.Fetch.Adapter

  alias Draught.Error.Normalized
  alias Draught.Web.Failure
  alias Draught.Web.Fetch.Transport.Configuration
  alias Draught.Web.Fetch.Transport.ConnectionDispatch
  alias Draught.Web.Fetch.Transport.ResponseHandler
  alias Draught.Web.Policy
  alias Draught.Web.Target

  @impl Draught.Web.Fetch.Adapter
  def fetch(url, %Policy{} = policy, configuration) do
    with {:ok, config} <- Configuration.new(configuration),
         {:ok, target} <- Target.new(url) do
      deadline = now() + policy.total_timeout_ms
      request(target, policy, config, deadline, [], %{})
    else
      {:error, _reason} -> {:error, Failure.target_blocked()}
    end
  end

  defp request(target, policy, config, deadline, redirects, seen) do
    with :ok <- before_deadline(deadline),
         :ok <- unseen(target, seen),
         {:ok, response} <- ConnectionDispatch.request(target, policy, config, deadline) do
      response
      |> ResponseHandler.handle(target, policy, redirects)
      |> continue(target, policy, config, deadline, redirects, seen)
    end
  end

  defp continue({:ok, response}, _target, _policy, _config, _deadline, _redirects, _seen) do
    {:ok, response}
  end

  defp continue(
         {:redirect, next, source},
         target,
         policy,
         config,
         deadline,
         redirects,
         seen
       ) do
    request(
      next,
      policy,
      config,
      deadline,
      [source | redirects],
      Map.put(seen, target.logical_url, true)
    )
  end

  defp continue(
         {:error, %Normalized{}} = result,
         _target,
         _policy,
         _config,
         _deadline,
         _redirects,
         _seen
       ) do
    result
  end

  defp before_deadline(deadline) do
    deadline
    |> then(&(now() < &1))
    |> deadline_result()
  end

  defp unseen(target, seen) do
    seen
    |> Map.has_key?(target.logical_url)
    |> unseen_result()
  end

  defp deadline_result(true) do
    :ok
  end

  defp deadline_result(false) do
    {:error, Failure.timeout()}
  end

  defp unseen_result(true) do
    {:error, Failure.redirect_rejected()}
  end

  defp unseen_result(false) do
    :ok
  end

  defp now do
    System.monotonic_time(:millisecond)
  end
end
