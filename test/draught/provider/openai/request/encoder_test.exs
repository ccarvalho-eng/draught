defmodule Draught.Provider.OpenAI.Request.EncoderTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Request.Encoder
  alias Draught.Provider.Request
  alias Draught.Tool.Call
  alias Draught.Tool.Result
  alias Draught.Tool.Specification

  test "encodes canonical messages, tools, generation options, and a model override" do
    assert {:ok, configuration} =
             Configuration.new(model: "configured-model", reasoning_field: :reasoning_content)

    request = complete_request()
    assert {:ok, body} = Encoder.encode(request, configuration, :complete)

    assert body["model"] == "configured-model"
    refute Map.has_key?(body, "stream")
    assert body["temperature"] == 0.4
    assert body["max_completion_tokens"] == 512
    assert body["stop"] == ["END"]
    assert body["seed"] == -1

    assert [system, user, assistant, tool] = body["messages"]
    assert system == %{"role" => "system", "content" => "Follow the rules"}
    assert user == %{"role" => "user", "content" => "Inspect the project"}

    assert assistant["role"] == "assistant"
    assert assistant["content"] == "Reading files."
    assert assistant["reasoning_content"] == "I should inspect first."
    refute Map.has_key?(assistant, "reasoning")

    assert [encoded_call] = assistant["tool_calls"]
    assert encoded_call["id"] == "call-1"
    assert encoded_call["type"] == "function"
    assert encoded_call["function"]["name"] == "read_file"

    assert {:ok, %{"path" => "mix.exs"}} =
             Jason.decode(encoded_call["function"]["arguments"])

    assert tool == %{
             "role" => "tool",
             "tool_call_id" => "call-1",
             "content" => "project source"
           }

    assert [encoded_tool] = body["tools"]

    assert encoded_tool == %{
             "type" => "function",
             "function" => %{
               "name" => "read_file",
               "description" => "Read a workspace file",
               "parameters" => %{
                 "type" => "object",
                 "properties" => %{"path" => %{"type" => "string"}}
               }
             }
           }
  end

  test "encodes streaming controls and uses the request model without an override" do
    assert {:ok, configuration} = Configuration.new(reasoning_field: :reasoning)
    request = minimal_request()

    assert {:ok, body} = Encoder.encode(request, configuration, :stream)

    assert body["model"] == "request-model"
    assert body["stream"] == true
    assert body["stream_options"] == %{"include_usage" => true}
    assert [%{"role" => "assistant", "content" => nil} = assistant] = body["messages"]
    assert [%{"id" => "call-2"}] = assistant["tool_calls"]
  end

  test "omits reasoning history when no compatible field is configured" do
    assert {:ok, configuration} = Configuration.new()

    assert {:ok, assistant} =
             Conversation.assistant(content: "visible content", reasoning: "private reasoning")

    assert {:ok, request} = Request.new(model: "model", messages: [assistant])

    assert {:ok, %{"messages" => [encoded]}} =
             Encoder.encode(request, configuration, :complete)

    assert encoded == %{"role" => "assistant", "content" => "visible content"}
  end

  test "rejects reasoning-only history when no compatible field is configured" do
    assert {:ok, configuration} = Configuration.new()
    assert {:ok, assistant} = Conversation.assistant(reasoning: "unrepresentable")
    assert {:ok, request} = Request.new(model: "model", messages: [assistant])

    assert {:error,
            %Normalized{
              kind: :configuration,
              code: "reasoning_field_required",
              retryable: false
            }} = Encoder.encode(request, configuration, :complete)
  end

  defp complete_request do
    assert {:ok, system} = Conversation.system("Follow the rules")
    assert {:ok, user} = Conversation.user("Inspect the project")
    call = call()

    assert {:ok, assistant} =
             Conversation.assistant(
               content: "Reading files.",
               reasoning: "I should inspect first.",
               tool_calls: [call]
             )

    assert {:ok, result} =
             Result.new(
               call_id: call.id,
               name: call.name,
               content: "project source",
               status: :success
             )

    assert {:ok, tool_message} = Conversation.tool(result)

    assert {:ok, request} =
             Request.new(
               model: "request-model",
               messages: [system, user, assistant, tool_message],
               tools: [tool_specification()],
               options: %{
                 temperature: 0.4,
                 max_output_tokens: 512,
                 stop: ["END"],
                 seed: -1
               }
             )

    request
  end

  defp minimal_request do
    assert {:ok, call} = Call.new(id: "call-2", name: "inspect", arguments: %{})
    assert {:ok, assistant} = Conversation.assistant(tool_calls: [call])
    assert {:ok, request} = Request.new(model: "request-model", messages: [assistant])
    request
  end

  defp call do
    assert {:ok, call} =
             Call.new(
               id: "call-1",
               name: "read_file",
               arguments: %{"path" => "mix.exs"}
             )

    call
  end

  defp tool_specification do
    assert {:ok, specification} =
             Specification.new(
               name: "read_file",
               description: "Read a workspace file",
               input_schema: %{
                 "type" => "object",
                 "properties" => %{"path" => %{"type" => "string"}}
               }
             )

    specification
  end
end
