---
id: uc-realtime-http-request-route-selection
title: Pick the handler for an inbound HTTP request by the meaning of its body, after the routing table has done its job
verdict: good
domain: realtime
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: community-report
sources:
  - https://github.com/yusukebe/hono-jev-router  (semantic routing middleware for the Hono HTTP framework; no numbers published)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify, then route to deterministic code, a specialist model, or a human)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms, "most queries about 100 ms")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot: send only what the question needs)
related: [uc-support-intent-routing-handlers, uc-realtime-ui-component-selection, uc-search-retrieval-query-intent-classification, uc-agents-harness-model-difficulty-routing, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev as routing middleware in my web framework?" Also: "we have one
`/agent` endpoint that has to fan out to six handlers — can jev pick?", "can we route by what
the request means instead of adding another path?", "is a model call safe inside the request
path?"

## Verdict

**Good.** A community middleware ships exactly this for the Hono framework
(github.com/yusukebe/hono-jev-router), and the shape fits: bounded handler set, text input you
already have, one label out, and a cheap fallback (the default handler) when the answer is not
confident. It is `good` rather than `strong` because that project publishes a design and no
numbers — no accuracy, no latency under load, no error budget.

The condition that makes it safe is architectural, not statistical: **jev never sees a request
the routing table could have resolved**. Method, path, content type, auth scope, tenant and
feature flags are decided deterministically and win first. jev resolves only the semantic
residue — the single endpoint that legitimately accepts several kinds of thing.

## What jev decides

State is the fields the question needs, not the request. Body excerpt (truncated), and at most
one or two structural hints your code already extracted:

```
handler: Choice
  instructions: {question: "Which handler should process this request body?",
                 focus: "What the caller is asking the service to do, not how the body is formatted."}
  criteria:
    create_task:   {what: "The body describes work the caller wants started",
                    not_for: "A question about work that already exists",
                    examples: ["deploy staging after the migration finishes"]}
    query_status:  {what: "The body asks for the state of something already known to the service"}
    cancel:        {what: "The body asks for in-flight work to stop"}
    ...
    unroutable:    {what: "The body does not describe any of the above, is empty, or is not a request at all"}
```

`unroutable` is not optional. A Choice is relative: without an explicit escape hatch, a health
probe or a malformed payload will be assigned one of your real handlers with a high number
attached.

Bands: at or above your fitted threshold, dispatch. Below it, dispatch to the default handler
(the one that asks the caller to be specific, or the one that was handling everything before
you added this). A timeout — set it below your p99 page budget — falls to the same default.

Closest jaggedness mode: **5, large state full of irrelevant detail**. Headers, cookies, trace
ids and a 200 KB JSON body are all irrelevant to "what is this asking for" and all of them
degrade the answer. Send a truncated excerpt of the one field that carries intent.

## What stays in code

The routing table. Authentication, authorisation, tenant resolution, rate limiting, schema
validation, CORS, idempotency keys, and every path that has a path. The timeout, the default
route, and the circuit breaker that stops calling jev when the API is slow or down — a
launch-day outage has already been reported for this API, so the middleware must degrade to
the default handler rather than to a 500. Body truncation and secret redaction before the
call. The dispatch itself.

## Numbers

Method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A 1,200-character
body excerpt plus one Choice over six handlers with criteria (~1,800 characters) is about 750
tokens, **= $0.000032 per request**. Multiply by your own request volume: this entry supplies
no volume, and no monthly total here would be sourced.

Latency is the number that decides this, and no source measures it for HTTP middleware. The
model page gives "70 to 500 ms, most queries about 100 ms"; a survey of 12,759 public posts
found a median self-reported latency of 76 ms (n=333) but also a median speed-up of 7x against
a claimed 193.6x, so treat the published range as a best case
(openchamber.dev/blog/jev-typesafe-ai). One integration author reports latency "slower from
Europe than the published 70 to 500 ms" (github.com/AboveColin/HA-Jev). Measure from your own
region before you put this in a synchronous path, and budget for the p99, not the median.

No accuracy figure exists for this task. The middleware repository publishes none.

## When the verdict flips

- **The path already tells you.** If callers can send to `/tasks` and `/status`, add the route.
  A network call to re-derive information the URL carried is `weak` at best.
- **The endpoint is on a hot path with a hard sub-100 ms budget.** Two network hops (yours and
  jev's) do not fit. Route deterministically and classify asynchronously.
- **The handler set is large or changes per tenant.** A Choice over a few dozen stable handlers
  is fine; a per-tenant catalog of hundreds is a retrieval problem first.
- **Routing has a side effect that is hard to undo** — charging a card, sending a message,
  deleting. Then the handler must confirm, or the route is not a routing decision.
- **Callers are adversarial.** The body is attacker-controlled text going straight into the
  state. Jaggedness mode 6 applies; a semantic router is not a security boundary, and auth must
  already have passed.

## Alternatives considered

- **More paths / an explicit `type` field in the body.** Free, exact, debuggable. Do this
  whenever you control the client. jev earns its place when you do not.
- **Regex or keyword rules on the body.** The incumbent in most codebases, and often correct.
  A public field report found keyword counting beating jev outright on one routing-shaped task
  (empryo.com/blog/jev-and-the-harness) — measure before replacing.
- **Small LLM with structured output.** Same decision, more latency, and JSON that can fail to
  parse inside your request path.
- **Frontier LLM.** Seconds. Not viable in a synchronous handler.
- **Fine-tuned intent classifier served locally.** No network hop at all, which is the whole
  ball game here — strongly preferred once you have the labelled requests. Your shadow log
  produces them.
- **Embeddings plus nearest handler prototype.** Cheap and local, but cannot express "not for"
  distinctions between two handlers that talk about the same nouns.

## Sources

- https://github.com/yusukebe/hono-jev-router — accessed 2026-09-19 (semantic HTTP routing
  middleware; no numbers published)
- https://docs.typesafe.ai/patterns/intent-routing.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://openchamber.dev/blog/jev-typesafe-ai/ — accessed 2026-09-19 (median latency 76 ms,
  n=333; median speed-up 7x)
- https://github.com/AboveColin/HA-Jev — accessed 2026-09-19 (latency "slower from Europe than
  the published 70 to 500 ms")
