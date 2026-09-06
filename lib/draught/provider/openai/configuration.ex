defmodule Draught.Provider.OpenAI.Configuration do
  @moduledoc """
  Validated connection and compatibility settings for an OpenAI-compatible endpoint.
  """

  alias Draught.Provider.OpenAI.Configuration.Builder
  alias Draught.Provider.OpenAI.Configuration.Credential
  alias Draught.Provider.OpenAI.Configuration.Limits
  alias Draught.Provider.OpenAI.Configuration.Retry
  alias Draught.Provider.OpenAI.Configuration.Timeouts
  alias Draught.Validation.Error

  defstruct base_url: "https://api.openai.com/v1",
            model: nil,
            credential: nil,
            headers: %{},
            timeouts: %Timeouts{},
            retry: %Retry{},
            limits: %Limits{},
            reasoning_field: :none

  @type reasoning_field :: :none | :reasoning | :reasoning_content
  @type t :: %__MODULE__{
          base_url: String.t(),
          model: String.t() | nil,
          credential: Credential.t() | nil,
          headers: %{optional(String.t()) => String.t()},
          timeouts: Timeouts.t(),
          retry: Retry.t(),
          limits: Limits.t(),
          reasoning_field: reasoning_field()
        }

  @doc "Builds validated provider configuration with bounded defaults."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    Builder.new(attributes)
  end
end

defimpl Inspect, for: Draught.Provider.OpenAI.Configuration do
  import Inspect.Algebra

  @spec inspect(Draught.Provider.OpenAI.Configuration.t(), Inspect.Opts.t()) ::
          Inspect.Algebra.t()
  def inspect(_configuration, _options) do
    concat(["#Draught.Provider.OpenAI.Configuration<redacted>"])
  end
end
