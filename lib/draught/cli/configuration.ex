defmodule Draught.CLI.Configuration do
  @moduledoc """
  Resolves bounded CLI settings while keeping configuration precedence separate from authority.
  """

  alias Draught.CLI.Configuration.Credential
  alias Draught.CLI.Configuration.Decoder
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Projection
  alias Draught.CLI.Configuration.Resolver
  alias Draught.CLI.Configuration.Source

  @enforce_keys [:profile, :provider, :base_url, :web, :risk, :origins]
  defstruct [
    :profile,
    :provider,
    :base_url,
    :model,
    :credential,
    :web,
    :risk,
    :origins,
    headers: %{}
  ]

  @type provider :: :ollama | :openai_compatible
  @type risk :: :deny | :ask | :allow
  @type t :: %__MODULE__{
          profile: String.t(),
          provider: provider(),
          base_url: String.t(),
          model: String.t() | nil,
          credential: Credential.t() | nil,
          headers: %{optional(String.t()) => String.t()},
          web: boolean(),
          risk: risk(),
          origins: %{optional(atom()) => Source.kind()}
        }

  @doc "Decodes one bounded JSON configuration source without creating atoms."
  @spec decode(Source.kind(), binary()) :: {:ok, Source.t()} | {:error, Error.t()}
  def decode(kind, json) do
    Decoder.decode(kind, json)
  end

  @doc "Resolves decoded sources using fixed precedence and trusted profile bindings."
  @spec resolve([Source.t()], map()) :: {:ok, t()} | {:error, Error.t()}
  def resolve(sources, environment \\ %{}) do
    Resolver.resolve(sources, environment)
  end

  @doc "Returns a JSON-compatible projection without credentials or header values."
  @spec safe_projection(t()) :: map()
  def safe_projection(%__MODULE__{} = configuration) do
    Projection.safe(configuration)
  end
end

defimpl Inspect, for: Draught.CLI.Configuration do
  import Inspect.Algebra

  @spec inspect(Draught.CLI.Configuration.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect(_configuration, _options) do
    concat(["#Draught.CLI.Configuration<redacted>"])
  end
end
