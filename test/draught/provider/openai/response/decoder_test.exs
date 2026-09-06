defmodule Draught.Provider.OpenAI.Response.DecoderTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Response.Decoder

  test "decodes text, DeepSeek reasoning, tool calls, finish reason, and usage details" do
    payload = %{
      "choices" => [
        %{
          "index" => 0,
          "message" => %{
            "role" => "assistant",
            "content" => "I will read it.",
            "reasoning_content" => "The file is required.",
            "tool_calls" => [
              %{
                "id" => "call-1",
                "type" => "function",
                "function" => %{
                  "name" => "read_file",
                  "arguments" => ~s({"path":"mix.exs"})
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 12,
        "completion_tokens" => 5,
        "total_tokens" => 17,
        "prompt_tokens_details" => %{"cached_tokens" => 3},
        "completion_tokens_details" => %{"reasoning_tokens" => 2}
      }
    }

    assert {:ok, response} = Decoder.decode(payload)
    assert response.finish_reason == :tool_calls

    assert response.message.content == [
             %Text{text: "I will read it."},
             %Reasoning{text: "The file is required."}
           ]

    assert [call] = response.message.tool_calls
    assert call.id == "call-1"
    assert call.name == "read_file"
    assert call.arguments == %{"path" => "mix.exs"}
    assert response.usage.input_tokens == 12
    assert response.usage.output_tokens == 5
    assert response.usage.cached_tokens == 3
    assert response.usage.reasoning_tokens == 2
  end

  test "decodes OpenRouter reasoning and optional usage" do
    payload = response_payload(%{"content" => "Answer", "reasoning" => "Analysis"}, "stop")

    assert {:ok, response} = Decoder.decode(payload)
    assert response.finish_reason == :stop
    assert response.usage == nil

    assert response.message.content == [
             %Text{text: "Answer"},
             %Reasoning{text: "Analysis"}
           ]
  end

  test "decodes an entirely filtered response without weakening ordinary messages" do
    payload = response_payload(%{"content" => nil}, "content_filter")

    assert {:ok, response} = Decoder.decode(payload)
    assert response.finish_reason == :content_filter
    assert response.message.content == []
    assert response.message.tool_calls == []

    incomplete = response_payload(%{"content" => nil}, "stop")

    assert {:error, %Normalized{kind: :protocol}} =
             Decoder.decode(incomplete)
  end

  test "maps unknown string finish reasons to other" do
    payload = response_payload(%{"content" => "Answer"}, "provider_specific_stop")

    assert {:ok, response} = Decoder.decode(payload)
    assert response.finish_reason == :other
  end

  test "accepts the DeepSeek cached-token field" do
    response = response_payload(%{"content" => "Answer"}, "stop")

    payload =
      Map.put(response, "usage", %{
        "prompt_tokens" => 9,
        "completion_tokens" => 3,
        "prompt_cache_hit_tokens" => 4
      })

    assert {:ok, response} = Decoder.decode(payload)
    assert response.usage.cached_tokens == 4
    assert response.usage.total_tokens == 12
  end

  test "rejects malformed response envelopes and choices" do
    invalid = [
      nil,
      %{},
      %{"choices" => []},
      %{
        "choices" => [
          choice(%{"content" => "one"}, "stop"),
          choice(%{"content" => "two"}, "stop")
        ]
      },
      %{
        "choices" => [
          %{
            "index" => 1,
            "message" => assistant(%{"content" => "Answer"}),
            "finish_reason" => "stop"
          }
        ]
      },
      %{
        "choices" => [
          %{
            "index" => 0,
            "message" => %{"role" => "user", "content" => "Answer"},
            "finish_reason" => "stop"
          }
        ]
      },
      response_payload(%{"content" => ["unsupported"]}, "stop"),
      response_payload(%{"content" => "Answer"}, nil)
    ]

    Enum.each(invalid, fn payload ->
      assert {:error, %Normalized{kind: :protocol, retryable: false}} = Decoder.decode(payload)
    end)
  end

  test "rejects ambiguous reasoning and malformed tool calls" do
    invalid = [
      response_payload(
        %{"content" => "Answer", "reasoning" => "one", "reasoning_content" => "two"},
        "stop"
      ),
      response_payload(%{"content" => nil, "tool_calls" => "invalid"}, "tool_calls"),
      tool_response(%{"type" => "custom"}),
      tool_response(%{"function" => %{"name" => "read_file", "arguments" => "{"}}),
      tool_response(%{"function" => %{"name" => "read_file", "arguments" => "[]"}}),
      tool_response(%{"function" => %{"name" => "bad name", "arguments" => "{}"}})
    ]

    Enum.each(invalid, fn payload ->
      assert {:error, %Normalized{kind: :protocol, retryable: false}} = Decoder.decode(payload)
    end)
  end

  test "rejects inconsistent or malformed usage" do
    invalid_usage = [
      %{"prompt_tokens" => 3, "completion_tokens" => 2, "total_tokens" => 8},
      %{"prompt_tokens" => -1, "completion_tokens" => 2},
      %{"prompt_tokens" => 3, "completion_tokens" => 2, "prompt_tokens_details" => []},
      %{
        "prompt_tokens" => 3,
        "completion_tokens" => 2,
        "prompt_cache_hit_tokens" => 1,
        "prompt_tokens_details" => %{"cached_tokens" => 2}
      },
      %{
        "prompt_tokens" => 3,
        "completion_tokens" => 2,
        "completion_tokens_details" => %{"reasoning_tokens" => 3}
      }
    ]

    Enum.each(invalid_usage, fn usage ->
      payload = Map.put(response_payload(%{"content" => "Answer"}, "stop"), "usage", usage)

      assert {:error, %Normalized{kind: :protocol, code: "invalid_usage"}} =
               Decoder.decode(payload)
    end)
  end

  test "never retains a rejected payload in the normalized error" do
    payload = response_payload(%{"content" => %{"secret-payload" => true}}, "stop")

    assert {:error, %Normalized{} = error} = Decoder.decode(payload)
    refute inspect(error) =~ "secret-payload"
  end

  defp response_payload(message, finish_reason) do
    %{"choices" => [choice(message, finish_reason)]}
  end

  defp choice(message, finish_reason) do
    %{
      "index" => 0,
      "message" => assistant(message),
      "finish_reason" => finish_reason
    }
  end

  defp assistant(fields) do
    Map.put(fields, "role", "assistant")
  end

  defp tool_response(overrides) do
    base = %{
      "id" => "call-1",
      "type" => "function",
      "function" => %{"name" => "read_file", "arguments" => "{}"}
    }

    call = Map.merge(base, overrides)
    response_payload(%{"content" => nil, "tool_calls" => [call]}, "tool_calls")
  end
end
