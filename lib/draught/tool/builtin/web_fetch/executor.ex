defmodule Draught.Tool.Builtin.WebFetch.Executor do
  @moduledoc false

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Approval
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Web.Capability
  alias Draught.Web.Failure
  alias Draught.Web.Fetch
  alias Draught.Web.Target

  @impl Draught.Tool.Executor
  def execute(%Call{arguments: %{"url" => url}} = call, %Context{} = context, _configuration) do
    with :ok <- enabled(context.web),
         {:ok, target} <- Target.new(url),
         :ok <-
           Approval.authorize(
             call,
             context,
             :network,
             target.logical_url,
             "bounded untrusted page"
           ) do
      Fetch.run(context.web, target.logical_url, context.policy.max_output_bytes)
    else
      {:error, %Draught.Validation.Error{}} -> {:error, Failure.invalid_result()}
      result -> result
    end
  end

  defp enabled(%Capability{} = capability) do
    capability
    |> Capability.enabled?(:fetch)
    |> enabled_result()
  end

  defp enabled_result(true) do
    :ok
  end

  defp enabled_result(false) do
    {:error, Failure.disabled(:fetch)}
  end
end
