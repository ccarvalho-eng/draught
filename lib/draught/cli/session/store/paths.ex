defmodule Draught.CLI.Session.Store.Paths do
  @moduledoc """
  Derives validated persistent-session paths from a workspace identity and user state directory.
  """

  alias Draught.CLI.Session.Store.Scope
  alias Draught.Session.Identifier
  alias Draught.Validation.Error

  @enforce_keys [
    :binding,
    :checkpoint,
    :journal,
    :key,
    :marker,
    :metadata,
    :preview,
    :root,
    :session,
    :workspace
  ]
  defstruct [
    :binding,
    :checkpoint,
    :journal,
    :key,
    :marker,
    :metadata,
    :preview,
    :root,
    :session,
    :workspace
  ]

  @type t :: %__MODULE__{
          binding: String.t(),
          checkpoint: String.t(),
          journal: String.t(),
          key: String.t(),
          marker: String.t(),
          metadata: String.t(),
          preview: String.t(),
          root: String.t(),
          session: String.t(),
          workspace: String.t()
        }

  @doc "Builds trusted user-state paths for one canonical workspace and session."
  @spec new(term(), term(), term()) :: Error.result(t())
  def new(workspace, identifier, environment) when is_map(environment) do
    with {:ok, id} <- Identifier.new(identifier),
         {:ok, scope} <- Scope.new(workspace, environment) do
      from_scope(scope, id)
    end
  end

  def new(_workspace, _identifier, _environment) do
    Error.single([:environment], :invalid_type, "must be a map")
  end

  @doc "Builds trusted paths for one validated identifier inside an existing scope."
  @spec from_scope(Scope.t(), term()) :: Error.result(t())
  def from_scope(%Scope{} = scope, identifier) do
    with {:ok, id} <- Identifier.new(identifier) do
      build(scope, id)
    end
  end

  defp build(scope, id) do
    session = Path.join(scope.sessions, id)
    workspace_digest = Path.basename(scope.workspace)
    key = digest(scope.root <> <<0>> <> workspace_digest <> ":" <> id)

    {:ok,
     %__MODULE__{
       binding: Path.join(session, "binding.json"),
       checkpoint: Path.join(session, "checkpoint.json"),
       journal: Path.join(session, "journal.jsonl"),
       key: key,
       marker: Path.join(session, ".draught-session"),
       metadata: Path.join(session, "metadata.json"),
       preview: Path.join(session, "preview.json"),
       root: scope.root,
       session: session,
       workspace: scope.workspace
     }}
  end

  defp digest(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end
end
