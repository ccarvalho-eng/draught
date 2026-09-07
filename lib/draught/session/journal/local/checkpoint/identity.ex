defmodule Draught.Session.Journal.Local.Checkpoint.Identity do
  @moduledoc """
  Computes the byte length and digest used to bind a checkpoint to journal content.
  """

  @doc "Encodes the byte length and SHA-256 digest of journal content."
  @spec encode(binary()) :: map()
  def encode(journal) do
    hash = :crypto.hash(:sha256, journal)

    %{
      "journal_bytes" => byte_size(journal),
      "journal_sha256" => Base.encode16(hash, case: :lower)
    }
  end
end
