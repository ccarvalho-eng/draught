defmodule Draught.Conversation.Attachment.Digest do
  @moduledoc """
  Computes and validates portable attachment content digests.

  Digests use lowercase hexadecimal SHA-256 so descriptors have one canonical
  representation across interchange formats.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @sha256 ~r/\A[0-9a-f]{64}\z/

  @doc "Returns the lowercase SHA-256 digest for binary attachment content."
  @spec from_content(binary()) :: String.t()
  def from_content(content) when is_binary(content) do
    content
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "Validates a lowercase SHA-256 digest at the given error path."
  @spec validate(term(), [term()]) :: Error.result(String.t())
  def validate(value, path) do
    with {:ok, digest} <- Value.string(value, path) do
      validate_shape(digest, path)
    end
  end

  defp validate_shape(digest, path) do
    @sha256
    |> Regex.match?(digest)
    |> shape_result(digest, path)
  end

  defp shape_result(true, digest, _path) do
    {:ok, digest}
  end

  defp shape_result(false, _digest, path) do
    Error.single(path, :invalid_value, "must be a lowercase SHA-256 digest")
  end
end
