# Tool execution

Draught registers provider-neutral tool definitions and executes canonical calls under an explicit workspace and policy context.

## Definition and registry

A definition contains:

- a stable portable name;
- a description;
- an object-rooted parameter schema;
- one risk class: `read`, `write`, `execute`, or `network`;
- an injected executor module and configuration.

Registries are immutable. Construction rejects malformed definitions and duplicate names while preserving declaration order for provider serialization.

Provider adapters serialize only portable specifications. Executor modules and their configuration remain inside the tool boundary.

## Invocation

`Draught.Tool.execute/3` reconstructs calls and contexts before dispatch. A context contains an absolute workspace path and a bounded policy. The policy declares allowed risk classes, the intended timeout, and the maximum accepted output size.

Invocation applies these checks in order:

1. registry lookup;
2. risk policy;
3. parameter validation;
4. executor dispatch;
5. result reconstruction and output bounds.

Unknown names, policy denials, invalid arguments, executor failures, malformed executor returns, and oversized output become canonical error results. The agent runner can return those results to a provider without exposing exceptions or adapter-specific values.

Timeout enforcement, cancellation, approval prompts, and duplicate-effect prevention are owned by the runner and session layers.

## Parameter schema subset

The supported JSON Schema subset is intentionally bounded:

- root type `object`;
- nested types `object`, `array`, `string`, `integer`, `number`, `boolean`, and `null`;
- `properties` and `required` for objects;
- boolean or schema-valued `additionalProperties`;
- `items` for arrays.

Schema and argument values also use Draught's aggregate size, nesting, collection, string, and object-key limits. Unsupported schema keywords have no execution semantics.

## Executor boundary

Executors implement the `Draught.Tool.Executor` behaviour. Its callback receives a canonical call, the explicit context, and injected configuration. It returns either UTF-8 content or a normalized execution error.

Draught does not compile plugin source, evaluate arbitrary Elixir, discover modules from user input, or use the process working directory as execution context. Tool implementations are application dependencies supplied explicitly when definitions are constructed.
