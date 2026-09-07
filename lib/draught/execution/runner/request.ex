defmodule Draught.Execution.Runner.Request do
  @moduledoc """
  Rebuilds provider requests at the runner boundary.

  Caller-supplied tool specifications are replaced with the canonical,
  declaration-ordered specifications from the injected tool registry.
  """

  alias Draught.Provider.Request
  alias Draught.Tool.Registry
  alias Draught.Validation.Error

  @doc "Reconstructs a request with specifications from the injected registry."
  @spec prepare(Request.t() | map() | keyword(), Registry.t()) :: Error.result(Request.t())
  def prepare(%Request{} = request, registry) do
    request
    |> Map.from_struct()
    |> prepare(registry)
  end

  def prepare(request, %Registry{} = registry) do
    with {:ok, canonical} <- Request.new(request) do
      Request.new(
        model: canonical.model,
        messages: canonical.messages,
        tools: Registry.specifications(registry),
        options: canonical.options
      )
    end
  end
end
