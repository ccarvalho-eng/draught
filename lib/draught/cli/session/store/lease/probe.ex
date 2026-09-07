defmodule Draught.CLI.Session.Store.Lease.Probe do
  @moduledoc """
  Probes lease endpoints and validates that their reported identity matches the requested session.
  """

  @different "draught-lease/v1:different"
  @request_prefix "draught-lease/v1:identify:"
  @same "draught-lease/v1:same"
  @timeout 500

  @doc "Identifies a Draught lease listener without trusting unrelated local services."
  @spec identity(pos_integer(), String.t()) :: :different | :same | {:error, term()}
  def identity(port, key) do
    case connect(port) do
      {:ok, socket} -> probe(socket, key)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Responds to one valid identity probe."
  @spec respond(term(), binary(), String.t()) :: :ok | {:error, term()}
  def respond(socket, request, key) do
    request
    |> requested_key()
    |> response(key)
    |> send_response(socket)
  end

  @doc false
  @spec timeout() :: pos_integer()
  def timeout do
    @timeout
  end

  defp connect(port) do
    :gen_tcp.connect(
      {127, 0, 0, 1},
      port,
      [:binary, active: false, packet: 4, packet_size: 256],
      @timeout
    )
  end

  defp probe(socket, key) do
    with :ok <- :gen_tcp.send(socket, @request_prefix <> key) do
      receive_identity(socket)
    end
  after
    :gen_tcp.close(socket)
  end

  defp receive_identity(socket) do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, @same} -> :same
      {:ok, @different} -> :different
      {:ok, _response} -> {:error, :invalid_response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp requested_key(@request_prefix <> key) when byte_size(key) == 64 do
    {:ok, key}
  end

  defp requested_key(_request) do
    :error
  end

  defp response({:ok, key}, key) do
    {:ok, @same}
  end

  defp response({:ok, _other_key}, _key) do
    {:ok, @different}
  end

  defp response(:error, _key) do
    :ignore
  end

  defp send_response({:ok, response}, socket) do
    :gen_tcp.send(socket, response)
  end

  defp send_response(:ignore, _socket) do
    :ok
  end
end
