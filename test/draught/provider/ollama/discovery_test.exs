defmodule Draught.Provider.Ollama.DiscoveryTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.Ollama.Discovery.Model

  defmodule HTTPServer do
    @moduledoc false

    @spec start(pid(), [{non_neg_integer(), binary()}]) :: {pid(), port(), String.t()}
    def start(owner, responses) do
      options = [:binary, active: false, packet: :raw, reuseaddr: true]
      {:ok, listener} = :gen_tcp.listen(0, options)
      {:ok, {_address, port}} = :inet.sockname(listener)
      pid = spawn(fn -> serve(listener, owner, responses) end)
      {pid, listener, "http://127.0.0.1:#{port}"}
    end

    defp serve(listener, owner, responses) do
      Enum.each(responses, fn response -> serve_one(listener, owner, response) end)
      :gen_tcp.close(listener)
    end

    defp serve_one(listener, owner, {status, body}) do
      {:ok, socket} = :gen_tcp.accept(listener)
      {:ok, request} = receive_request(socket, "")
      send(owner, {:http_request, request})
      :ok = :gen_tcp.send(socket, response(status, body))
      :gen_tcp.close(socket)
    end

    defp receive_request(socket, received) do
      case header_and_body(received) do
        {:ok, header, body, length} when byte_size(body) >= length ->
          {:ok, header <> "\r\n\r\n" <> binary_part(body, 0, length)}

        _incomplete ->
          with {:ok, data} <- :gen_tcp.recv(socket, 0, 2_000) do
            receive_request(socket, received <> data)
          end
      end
    end

    defp header_and_body(received) do
      case :binary.split(received, "\r\n\r\n") do
        [header, body] -> {:ok, header, body, content_length(header)}
        [_header] -> :incomplete
      end
    end

    defp content_length(header) do
      header
      |> String.split("\r\n")
      |> Enum.find_value(0, fn line ->
        case String.split(line, ":", parts: 2) do
          [name, value] -> content_length(name, value)
          _parts -> nil
        end
      end)
    end

    defp content_length(name, value) do
      if String.downcase(name) == "content-length" do
        value
        |> String.trim()
        |> String.to_integer()
      end
    end

    defp response(status, body) do
      [
        "HTTP/1.1 #{status} #{reason(status)}\r\n",
        "content-type: application/json\r\n",
        "content-length: #{byte_size(body)}\r\n",
        "connection: close\r\n\r\n",
        body
      ]
    end

    defp reason(200) do
      "OK"
    end

    defp reason(_status) do
      "Not Found"
    end
  end

  test "lists installed model names through the native API" do
    body = Jason.encode!(%{"models" => [%{"name" => "qwen3:8b"}, %{"model" => "coder:7b"}]})
    {_pid, listener, base_url} = HTTPServer.start(self(), [{200, body}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    assert {:ok, ["qwen3:8b", "coder:7b"]} = Discovery.list(base_url: base_url)
    assert_receive {:http_request, "GET /api/tags " <> request}
    refute request =~ "authorization:"
  end

  test "maps native model details into canonical capabilities" do
    body =
      Jason.encode!(%{
        "capabilities" => ["completion", "tools", "thinking"],
        "model_info" => %{
          "general.architecture" => "qwen3",
          "qwen3.context_length" => 32_768
        }
      })

    {_pid, listener, base_url} = HTTPServer.start(self(), [{200, body}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    assert {:ok, %Model{} = model} = Discovery.fetch("qwen3:8b", base_url: base_url)
    assert model.name == "qwen3:8b"
    assert model.capabilities.chat
    assert model.capabilities.streaming
    assert model.capabilities.tool_calls
    assert model.capabilities.reasoning
    assert model.capabilities.usage
    assert model.capabilities.context_window == 32_768

    assert_receive {:http_request, "POST /api/show " <> request}
    assert request =~ ~s({"model":"qwen3:8b"})
    refute request =~ "authorization:"
  end

  test "reports missing models without retaining response bodies" do
    body = Jason.encode!(%{"error" => "model contains sensitive local detail"})
    {_pid, listener, base_url} = HTTPServer.start(self(), [{404, body}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    assert {:error,
            %Normalized{
              kind: :configuration,
              code: "ollama_model_not_found",
              hint: "Run `ollama pull <model>` with the configured model name."
            } = error} = Discovery.fetch("missing:latest", base_url: base_url)

    refute inspect(error) =~ "sensitive local detail"
  end

  test "normalizes an unavailable service" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false])
    {:ok, {_address, port}} = :inet.sockname(listener)
    :ok = :gen_tcp.close(listener)

    assert {:error,
            %Normalized{
              kind: :transport,
              code: "ollama_unavailable",
              retryable: true
            }} = Discovery.list(base_url: "http://127.0.0.1:#{port}", connect_timeout_ms: 100)
  end

  test "rejects malformed discovery payloads" do
    {_pid, listener, base_url} = HTTPServer.start(self(), [{200, ~s({"models":"invalid"})}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    assert {:error,
            %Normalized{
              kind: :protocol,
              code: "invalid_ollama_response",
              retryable: false
            }} = Discovery.list(base_url: base_url)
  end

  test "rejects invalid model names and discovery HTTP modules" do
    assert {:error, %Normalized{code: "invalid_ollama_model"}} = Discovery.fetch("")

    assert {:error, %Normalized{code: "invalid_ollama_discovery_http"}} =
             Discovery.list([], String)
  end

  test "rejects oversized discovery responses without retaining their contents" do
    body = Jason.encode!(%{"models" => [%{"name" => "sensitive-model-name"}]})
    {_pid, listener, base_url} = HTTPServer.start(self(), [{200, body}])
    on_exit(fn -> :gen_tcp.close(listener) end)

    assert {:error,
            %Normalized{
              kind: :protocol,
              code: "ollama_response_too_large",
              retryable: false
            } = error} = Discovery.list(base_url: base_url, max_response_bytes: 4)

    refute inspect(error) =~ "sensitive-model-name"
  end
end
