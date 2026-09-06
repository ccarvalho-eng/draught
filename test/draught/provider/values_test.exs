defmodule Draught.Provider.ValuesTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Conversation.Message.Assistant
  alias Draught.Error.Normalized
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Options
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Tool.Call
  alias Draught.Tool.Specification
  alias Draught.Validation.Error

  describe "generation options" do
    test "uses explicit neutral defaults and accepts bounded values" do
      assert {:ok, %Options{} = defaults} = Options.new()
      assert defaults == %Options{temperature: nil, max_output_tokens: nil, stop: [], seed: nil}

      assert {:ok, options} =
               Options.new(temperature: 0.4, max_output_tokens: 512, stop: ["END"], seed: -1)

      assert options.temperature == 0.4
      assert options.max_output_tokens == 512
      assert options.stop == ["END"]
      assert options.seed == -1
    end

    test "rejects invalid options" do
      invalid = [
        [temperature: 3],
        [max_output_tokens: 0],
        [stop: "END"],
        [stop: [""]],
        [seed: 1.0]
      ]

      Enum.each(invalid, fn options ->
        assert {:error, %Error{}} = Options.new(options)
      end)
    end
  end

  describe "usage" do
    test "derives totals and validates optional subtotals" do
      assert {:ok, usage} = Usage.new(input_tokens: 5, output_tokens: 3)
      assert usage.total_tokens == 8
      assert usage.cached_tokens == 0
      assert usage.reasoning_tokens == 0

      assert {:ok, explicit} =
               Usage.new(
                 input_tokens: 5,
                 output_tokens: 3,
                 total_tokens: 8,
                 cached_tokens: 2,
                 reasoning_tokens: 1
               )

      assert explicit.total_tokens == 8
    end

    test "rejects inconsistent or malformed counts" do
      invalid = [
        [input_tokens: -1, output_tokens: 1],
        [input_tokens: 1, output_tokens: -1],
        [input_tokens: 1, output_tokens: 1, total_tokens: 3],
        [input_tokens: 1, output_tokens: 1, cached_tokens: 2],
        [input_tokens: 1, output_tokens: 1, reasoning_tokens: 2]
      ]

      Enum.each(invalid, fn usage ->
        assert {:error, %Error{}} = Usage.new(usage)
      end)
    end
  end

  describe "capabilities" do
    test "advertises only explicit features and negotiates requirements" do
      assert {:ok, capabilities} = Capabilities.new(chat: true, context_window: 8_192)
      assert Capabilities.supports?(capabilities, :chat)
      refute Capabilities.supports?(capabilities, :streaming)
      assert :ok = Capabilities.require(capabilities, :chat)

      assert {:error, %Normalized{kind: :capability, retryable: false}} =
               Capabilities.require(capabilities, :tool_calls)
    end

    test "rejects malformed flags and context windows" do
      assert {:error, %Error{}} = Capabilities.new(chat: :yes)
      assert {:error, %Error{}} = Capabilities.new(context_window: 0)
    end
  end

  describe "requests and responses" do
    test "normalizes ordered messages, tools, and options" do
      request = request()

      assert [%Draught.Conversation.Message.User{}] = request.messages
      assert [tool] = request.tools
      assert tool.name == "read_file"
      assert request.options.temperature == 0
    end

    test "rejects empty messages, duplicate tools, and invalid nested structs" do
      assert {:error, %Error{}} = Request.new(model: "model", messages: [])

      tool = tool_specification()

      assert {:error, %Error{}} =
               Request.new(model: "model", messages: [user()], tools: [tool, tool])

      invalid_message = %Draught.Conversation.Message.User{
        content: %Draught.Conversation.Content.Text{text: ""}
      }

      assert {:error, %Error{}} = Request.new(model: "model", messages: [invalid_message])
    end

    test "validates external nested values and collection types" do
      external = %{
        model: "model",
        messages: [%{role: :user, content: "hello"}],
        tools: [
          %{name: "read_file", description: "Read", input_schema: %{"type" => "object"}}
        ],
        options: %{max_output_tokens: 128}
      }

      assert {:ok, %Request{} = request} = Request.new(external)
      assert request.options.max_output_tokens == 128
      assert {:error, %Error{}} = Request.new(model: "model", messages: "invalid")
      assert {:error, %Error{}} = Request.new(model: "model", messages: [42])
      assert {:error, %Error{}} = Request.new(model: "model", messages: [%{role: :user}])
      assert {:error, %Error{}} = Request.new(model: "model", messages: [user()], tools: :invalid)
      assert {:error, %Error{}} = Request.new(model: "model", messages: [user()], tools: [42])

      assert {:error, %Error{}} =
               Request.new(model: "model", messages: [user()], tools: [%{name: "bad"}])
    end

    test "enforces finish reason and tool-call relationships" do
      assert {:ok, response} = response()
      assert response.finish_reason == :stop

      assert {:ok, filtered} =
               Response.new(message: response.message, finish_reason: "content_filter")

      assert filtered.finish_reason == :content_filter

      assert {:ok, call} = Call.new(id: "call-1", name: "read_file")
      assert {:ok, assistant} = Conversation.assistant(tool_calls: [call])

      assert {:ok, tool_response} =
               Response.new(message: assistant, finish_reason: :tool_calls)

      assert tool_response.message.tool_calls == [call]
      assert {:error, %Error{}} = Response.new(message: assistant, finish_reason: :stop)

      assert {:error, %Error{}} =
               Response.new(message: response.message, finish_reason: :tool_calls)

      invalid = %Assistant{content: [], tool_calls: []}
      assert {:error, %Error{}} = Response.new(message: invalid, finish_reason: :stop)
    end
  end

  defp request do
    assert {:ok, request} =
             Request.new(
               model: "model",
               messages: [user()],
               tools: [tool_specification()],
               options: %{temperature: 0}
             )

    request
  end

  defp user do
    assert {:ok, user} = Conversation.user("Hello")
    user
  end

  defp tool_specification do
    assert {:ok, tool} =
             Specification.new(
               name: "read_file",
               description: "Read a file",
               input_schema: %{"type" => "object"}
             )

    tool
  end

  defp response do
    assert {:ok, message} = Conversation.assistant(content: "Hello")
    assert %Assistant{} = message
    Response.new(message: message, finish_reason: :stop)
  end
end
