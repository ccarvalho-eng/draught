# Web access

Draught treats web search and page fetching as separate optional capabilities. Both are disabled by default. Remote text, result metadata, redirect locations, and adapter output remain untrusted data and cannot change the tool registry, execution policy, approval policy, workspace, timeouts, or loop budget.

## Configuration

`Draught.Web.Policy.resolve/3` resolves global, session, and command layers in increasing precedence. A layer may override either operation without enabling the other:

```elixir
{:ok, policy} =
  Draught.Web.Policy.resolve(
    [fetch: true],
    [search: true],
    [fetch: false]
  )

Draught.Web.Policy.status(policy)
# => %{fetch: :disabled, search: :enabled}
```

The resolver is pure and does not read application environment, files, or process state. Interfaces are responsible for reading configuration sources and passing their values in the documented order. The CLI and library consumers resolve search and fetch independently.

An enabled operation also requires an explicit adapter. The included fetch adapter uses guarded HTTP(S) retrieval. The included SearXNG adapter supports a configured JSON endpoint through that same fetch transport. Other search services remain injectable because result schemas, authentication requirements, and usage policies differ.

For CLI tasks, `--web` enables the included `web_fetch` tool and `--web-search` enables `web_search`. Search additionally requires an explicit SearXNG-compatible endpoint from `--web-search-url`, `DRAUGHT_WEB_SEARCH_URL`, or trusted user configuration. `DRAUGHT_WEB` and `DRAUGHT_WEB_SEARCH` provide the corresponding permissions under the documented precedence rules. Both default to disabled. Project configuration may disable either permission but cannot enable one or choose an endpoint. Enabling either operation does not bypass the network risk class or approval policy.

```elixir
{:ok, web} =
  Draught.Web.Capability.new(
    policy: [fetch: true],
    fetch: {Draught.Web.Fetch.Transport.Mint, []}
  )

{:ok, registry} = Draught.Tool.Builtin.registry(web: web)

{:ok, execution_policy} =
  Draught.Tool.Execution.Policy.new(allowed_risks: [:read, :network])

{:ok, context} =
  Draught.Tool.Execution.Context.new(
    workspace: File.cwd!(),
    policy: execution_policy,
    web: web
  )
```

The standard registry omits disabled web operations, so providers do not receive their definitions. Each executor checks the capability again before requesting approval or performing an effect. Admitting `:network` risk does not itself enable web access. Under the default approval policy, each admitted web operation still returns `approval_required` until an interface records an explicit allow decision. Approval metadata includes the complete bounded search query or canonical outbound URL, including its query string; metadata containing terminal control or Unicode display-control characters is rejected before the effect. Provenance stored after the operation removes query strings and fragments.

## Fetch transport

The included fetch adapter applies the following controls to the initial target and every redirect:

- only `http` and `https` URLs;
- no embedded credentials, fragments, ambiguous numeric hosts, or non-ASCII hostnames;
- DNS resolution through an explicit resolver boundary;
- rejection when any resolved address is loopback, private, link-local, carrier-grade NAT, multicast, documentation, benchmarking, transition, reserved, or otherwise outside the accepted global-unicast ranges;
- a new address-pinned HTTP/1 connection for each hop, with the original hostname used only for the HTTP Host value, TLS SNI, and certificate verification;
- no proxy configuration, cookies, authorization headers, client credentials, shared connection pool, decompression, filesystem access, or redirect forwarding;
- explicit redirect, header, response-byte, request-time, total-time, and content-type limits;
- a separate canonical tool-output limit checked against the exact JSON-encoded size before the envelope is allocated;
- `Accept-Encoding: identity`, with compressed responses rejected;
- valid UTF-8 content from a small text and structured-text media-type allowlist.

Redirects are followed manually. HTTPS-to-HTTP downgrades, loops, missing or duplicate locations, excessive redirect chains, and targets that fail a fresh DNS/address check are rejected.

## Search adapters

A search adapter implements `Draught.Web.Search.Adapter` and returns a list of maps or `Draught.Web.Search.Result.Item` values containing `title`, `url`, and `snippet`. Draught reconstructs every item, caps the result count and field sizes, removes query strings and fragments from provenance URLs, and renders one fixed JSON envelope.

`Draught.Web.Search.Transport.Searxng` accepts an explicit endpoint whose [SearXNG search API](https://docs.searxng.org/dev/search_api.html) enables JSON responses:

```elixir
{:ok, web} =
  Draught.Web.Capability.new(
    policy: [search: true],
    search:
      {Draught.Web.Search.Transport.Searxng,
       endpoint: "https://search.example/search"}
  )
```

The endpoint must be an HTTP(S) URL without credentials, fragments, or an existing query string. The adapter adds the bounded query, `format=json`, and moderate safe-search parameters, then delegates the request to the guarded Mint fetch transport. Search responses therefore receive the same address, redirect, content-type, byte, and time validation as page fetching. Returned JSON must contain a `results` list with bounded `title` and `url` strings; missing snippets become empty strings. Some public SearXNG instances disable JSON responses, so the configured endpoint must expose that response format.

Search adapters receive the effective `Draught.Web.Policy`. Adapter invocation is supervised and bounded by the total operation timeout, and returned values are reconstructed through the result limits. Custom adapter modules and their configuration are trusted application code: they must apply the same isolation principles to their own HTTP client and must not read ambient credentials or proxy settings. Credentials explicitly supplied in trusted adapter configuration remain the host application's responsibility and must not appear in results, errors, events, or logs.

Custom fetch adapters are also trusted application code. The capability boundary validates their callback and bounds their execution and returned value, but only the included Mint transport provides Draught's address-pinned egress checks.

## Trust and persistence

Successful web tools return a canonical `Draught.Tool.Result` with provenance fixed to `origin: :web` and `trust: :untrusted`. Model-visible content is JSON-escaped inside an envelope whose trust label and source fields are created by Draught rather than by the remote page.

Session journals preserve the trust classification and sanitized source URLs even when tool-output retention is disabled. Replayed content remains a tool-role message. It is never reconstructed as a system, developer, or user instruction and cannot restore a web capability. Persistent sessions bind the effective web permissions, adapter identities, and configured search endpoint; resume rejects any drift before provider execution.

Telemetry records only the closed `origin` and `trust` atoms on web tool spans, including failed operations. URLs, queries, result text, response headers, resolved addresses, and adapter configuration are excluded.

## Prompt injection

Remote content can still contain persuasive or adversarial instructions. Draught does not claim to determine whether text is safe. Injection detectors may add warnings, but authorization does not depend on a classifier.

Security relies on independent controls after every model proposal: registered tools, web capability checks, risk admission, typed arguments, approval decisions, workspace confinement, byte and time limits, sequential execution, duplicate-batch detection, and the runner iteration budget. A write, command, or further network call suggested by web content is evaluated like any other call.

## Limitations

These are application controls inside the BEAM VM. They do not provide a hard CPU or memory quota, prevent every effect available to an approved executable, or defend against a compromised resolver, network stack, kernel, or operator-controlled route. Platform DNS work may finish after its caller is cancelled. Deployments requiring hard egress or resource isolation should add a container or operating-system sandbox and an egress firewall or proxy.

Content type and TLS identity establish transport properties, not benign intent. Retrieved content remains untrusted regardless of its source or media type.
