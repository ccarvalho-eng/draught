defmodule Draught.Session.Journal.Codec.Outcome do
  @moduledoc """
  Encodes and decodes successful or failed runner outcomes for journal records.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.Response
  alias Draught.Session.Journal.Codec.Error
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical runner outcome."
  @spec encode(Draught.Execution.Runner.result(), Retention.t()) :: map()
  def encode({:ok, %Response{} = response}, %Retention{} = retention) do
    encoded = Draught.Session.Journal.Codec.Response.encode(response, retention)
    %{"response" => encoded, "status" => "ok"}
  end

  def encode({:error, %Normalized{} = error}, %Retention{}) do
    %{"error" => Error.encode(error), "status" => "error"}
  end

  @doc "Decodes a canonical runner outcome."
  @spec decode(term()) :: {:ok, Draught.Execution.Runner.result()} | :error
  def decode(%{"response" => response, "status" => "ok"}) do
    with {:ok, canonical} <- Draught.Session.Journal.Codec.Response.decode(response) do
      {:ok, {:ok, canonical}}
    end
  end

  def decode(%{"error" => error, "status" => "error"}) do
    with {:ok, canonical} <- Error.decode(error) do
      {:ok, {:error, canonical}}
    end
  end

  def decode(_data) do
    :error
  end
end
