defmodule Draught.CLI.Session.Catalog.Entry do
  @moduledoc """
  Projects bounded, non-secret session metadata for selection and rendering.

  Unavailable entries retain only their validated immutable identifier. Their
  untrusted binding or metadata content is never rendered.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Catalog.Display
  alias Draught.CLI.Session.Catalog.Metadata

  @enforce_keys [
    :archive,
    :availability,
    :id,
    :label,
    :model,
    :preview,
    :profile,
    :provider
  ]
  defstruct [:archive, :availability, :id, :label, :model, :preview, :profile, :provider]

  @type archive :: :active | :unknown | {:archived, DateTime.t()}
  @type availability :: :available | :unavailable
  @type t :: %__MODULE__{
          archive: archive(),
          availability: availability(),
          id: String.t(),
          label: String.t(),
          model: String.t() | nil,
          preview: String.t() | nil,
          profile: String.t() | nil,
          provider: String.t() | nil
        }

  @doc "Builds an available entry from validated binding and metadata records."
  @spec available(String.t(), Binding.t(), Metadata.t()) :: {:ok, t()} | {:error, :unsafe}
  def available(id, %Binding{} = binding, %Metadata{} = metadata) do
    available(id, binding, metadata, nil)
  end

  @doc "Builds an available entry with an optional validated latest-message preview."
  @spec available(String.t(), Binding.t(), Metadata.t(), String.t() | nil) ::
          {:ok, t()} | {:error, :unsafe}
  def available(id, %Binding{} = binding, %Metadata{} = metadata, preview) do
    with {:ok, label} <- Display.validate(metadata.label || id),
         {:ok, model} <- Display.validate(binding.model),
         {:ok, safe_preview} <- optional_preview(preview),
         {:ok, profile} <- Display.validate(binding.profile),
         {:ok, provider} <- Display.validate(binding.provider) do
      {:ok,
       %__MODULE__{
         archive: archive(metadata.archived_at),
         availability: :available,
         id: id,
         label: label,
         model: model,
         preview: safe_preview,
         profile: profile,
         provider: provider
       }}
    end
  end

  @doc "Builds a fail-closed entry without projecting invalid record content."
  @spec unavailable(String.t()) :: t()
  def unavailable(id) do
    %__MODULE__{
      archive: :unknown,
      availability: :unavailable,
      id: id,
      label: id,
      model: nil,
      preview: nil,
      profile: nil,
      provider: nil
    }
  end

  defp archive(nil) do
    :active
  end

  defp archive(%DateTime{} = timestamp) do
    {:archived, timestamp}
  end

  defp optional_preview(nil) do
    {:ok, nil}
  end

  defp optional_preview(preview) do
    Display.validate(preview)
  end
end
