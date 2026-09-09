defmodule Draught.CLI.Session.Catalog.Preview do
  @moduledoc """
  Defines a bounded, versioned preview of the latest successful user message.

  Preview records are derived catalog data. Conversation journals remain the
  authoritative source of session history.
  """

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.UI.SafeLine
  alias Draught.Session.Identifier

  @maximum_graphemes 72
  @maximum_source_bytes 4_096
  @schema "draught.cli.session.preview/v1"

  @enforce_keys [:id, :text, :version]
  defstruct [:id, :text, :version]

  @type t :: %__MODULE__{id: String.t(), text: String.t(), version: 1}

  @doc "Builds a canonical single-line preview from one validated session prompt."
  @spec new(term(), term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def new(id, prompt) when is_binary(prompt) do
    with {:ok, validated_id} <- Identifier.new(id),
         true <- String.valid?(prompt),
         {:ok, text} <- normalize(prompt) do
      {:ok, %__MODULE__{id: validated_id, text: text, version: 1}}
    else
      _result -> {:error, Failure.invalid_preview()}
    end
  end

  def new(_id, _prompt) do
    {:error, Failure.invalid_preview()}
  end

  @doc "Encodes one canonical preview as a closed JSON object."
  @spec encode(t()) :: {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(%__MODULE__{id: id, text: text, version: 1}) do
    with {:ok, preview} <- new(id, text),
         true <- preview.text == text,
         {:ok, encoded} <-
           Jason.encode(%{"id" => id, "schema" => @schema, "text" => text}) do
      {:ok, encoded}
    else
      _result -> {:error, Failure.invalid_preview()}
    end
  end

  def encode(%__MODULE__{}) do
    {:error, Failure.invalid_preview()}
  end

  @doc "Decodes one strict preview record without creating atoms."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(encoded) when is_binary(encoded) do
    with {:ok, value} <- Jason.decode(encoded),
         {:ok, preview} <- decode_value(value) do
      {:ok, preview}
    else
      _result -> {:error, Failure.invalid_preview()}
    end
  end

  def decode(_encoded) do
    {:error, Failure.invalid_preview()}
  end

  defp decode_value(%{"id" => id, "schema" => @schema, "text" => text} = value)
       when map_size(value) == 3 do
    with {:ok, preview} <- new(id, text),
         true <- preview.text == text do
      {:ok, preview}
    else
      _result -> {:error, Failure.invalid_preview()}
    end
  end

  defp decode_value(_value) do
    {:error, Failure.invalid_preview()}
  end

  defp normalize(prompt) do
    text =
      prompt
      |> SafeLine.text(@maximum_source_bytes)
      |> String.split()
      |> Enum.join(" ")
      |> truncate()

    case text do
      "" -> {:error, Failure.invalid_preview()}
      _text -> {:ok, text}
    end
  end

  defp truncate(text) do
    case String.length(text) do
      length when length <= @maximum_graphemes -> text
      _length -> String.slice(text, 0, @maximum_graphemes - 1) <> "…"
    end
  end
end
