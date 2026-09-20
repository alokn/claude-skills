---
id: gt-api-and-primitives
title: The API, the three primitives, and every answer field
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/api.md  (endpoint, request/response schema, error codes)
  - https://docs.typesafe.ai/primitives.md  (question definition, answer fields, question independence, backtick paths)
  - https://docs.typesafe.ai/primitives/choice.md  (Choice fields, 255 options, structured criteria)
  - https://docs.typesafe.ai/primitives/score.md  (Score fields, levels, legend, score arithmetic)
  - https://docs.typesafe.ai/primitives/noul.md  (Noul fields, no confidence)
  - https://docs.typesafe.ai/primitives/advanced.md  (structured instructions and criteria)
  - https://docs.typesafe.ai/concepts/state.md  (state formats)
  - https://docs.typesafe.ai/introduction/quickstart.md  (cURL, request/response JSON, Python SDK)
  - https://docs.typesafe.ai/sdk/python/usage.md  (Python usage, env vars, retries, errors)
  - https://docs.typesafe.ai/sdk/javascript.md  (JS install and usage)
  - https://docs.typesafe.ai/sdk/python/api/retries.md  (RetryPolicy defaults)
  - https://docs.typesafe.ai/sdk/javascript/api/interfaces/RetryPolicy.md  (JS retry defaults)
  - https://docs.typesafe.ai/sdk/python/api/exceptions.md  (Python exception classes)
  - https://docs.typesafe.ai/migrating-to-v1.md  (preview → v1 field renames)
---

## Endpoint

```http
POST https://api.typesafe.ai/v1/systemone
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

— https://docs.typesafe.ai/api.md. `GET /v1/models` lists the names an account may send in `model`
(https://docs.typesafe.ai/models.md).

## Request body

Three required top-level fields: `state` (`string | object | array`), `model` (`string`), and
`questions` (`map<string, Question>`). "You choose each key; answers come back under the same keys."
The key "is not sent to the underlying model and is not used in inference."
(https://docs.typesafe.ai/api.md)

Verbatim request from the quickstart (https://docs.typesafe.ai/introduction/quickstart.md):

```json
{
  "state": "Hi, I've been trying to connect my Stripe account for 3 days and it keeps failing. I'm losing sales. Please help ASAP.",
  "model": "jev-latest",
  "questions": {
    "department": {
      "type": "choice",
      "instructions": "Which team should handle this",
      "criteria": {
        "billing": "Payment or subscription issues",
        "technical": "Bugs or integration problems",
        "sales": "Pricing or account questions"
      }
    },
    "frustration": {
      "type": "score",
      "instructions": "How frustrated the customer appears",
      "criteria": [
        "Calm, just stating facts",
        "Frustrated but civil",
        "Very angry, strong language"
      ]
    },
    "is_urgent": {
      "type": "noul",
      "instructions": "The message conveys urgency or time-sensitivity"
    }
  }
}
```

Matching response, verbatim from the same page:

```json
{
  "model": "jev-latest",
  "answers": {
    "department": {
      "type": "choice",
      "choice": "billing",
      "probabilities": { "billing": 0.84, "technical": 0.159, "sales": 0.001 },
      "confidence": 0.596
    },
    "frustration": {
      "type": "score",
      "score": 1.035,
      "legend": {
        "0": "Calm, just stating facts",
        "1": "Frustrated but civil",
        "2": "Very angry, strong language"
      },
      "confidence": 0.842
    },
    "is_urgent": { "type": "noul", "noul": 0.999 }
  },
  "usage": { "input_tokens": 312, "output_tokens": 48 }
}
```

`usage` is required in the response and carries `input_tokens` and `output_tokens`
(https://docs.typesafe.ai/api.md).

## Defining a question

> "Every question has an ID, a `type`, and `instructions`. Choice and Score questions also take `criteria`, which define the options for a Choice question or the levels for a Score. Noul questions accept `criteria` as an optional clarification of what yes and no mean."
> — https://docs.typesafe.ai/primitives.md

> "Question IDs are for your code. They are not sent to the model. Write the complete question in `instructions`, even when the ID seems self-explanatory."
> — same page

### Choice

* `type`: always `"choice"`.
* `instructions`: `string | object | array`, required — "What the model should decide."
* `criteria`: `map<string, string | null>`, required — "A map of option to rubric description; use null when an option needs no extra detail." (https://docs.typesafe.ai/api.md)

Answer fields: `type`, `choice` ("The option with the highest probability"), `probabilities`
("Every option mapped to its probability (floats that sum to 1)"), `confidence`
("How certain the model is, derived from probabilities").

Limit: "A Choice question accepts up to 255 options, and adding options costs a few tokens each"
(https://docs.typesafe.ai/primitives/choice.md). Guidance: "Add an `other` or `none of the above`
option when the list might not cover every input."

### Score

* `type`: always `"score"`.
* `instructions`: `string | object | array`, required.
* `criteria`: array, required — "An ordered array of level descriptions. You must include at least two levels." (https://docs.typesafe.ai/api.md). The Score page adds: "Needs at least two levels and takes up to 10."

Answer fields: `type`, `score`, `legend`, `probabilities`, `confidence`. Definitions verbatim from
https://docs.typesafe.ai/primitives/score.md:

* `probabilities`: "The probability of each level, keyed by level number as a string. The sum of all values is 1."
* `score`: "The position on the level number line... It's each level number multiplied by its probability, added up: 0 x 0.0 + 1 x 0.70 + 2 x 0.30 = 1.30."
* `legend`: "Each level number mapped back to its description."

> "Different distributions can produce the same score. A score of 1.0 can mean all probability is on level 1, or half is on each of levels 0 and 2. Read `probabilities` and `confidence` alongside the score to distinguish these cases."

The Python SDK "keys `probabilities` and `legend` by integer level rather than by string."

### Noul

* `type`: `"noul"`, required.
* `instructions`: required — "The yes/no question to evaluate."
* `criteria`: optional object with `true` and `false` descriptions.

Answer fields: `type` and `noul` only — "The yes/no answer on a scale from 0 (no) to 1 (yes)."
There is no `confidence` and no `probabilities` on a Noul
(https://docs.typesafe.ai/primitives/noul.md).

## Structured instructions and criteria

_Adjudication: the HTTP API reference types Choice `criteria` values as `string | null`, while the
Advanced: structure page and the SDK types accept nested objects and arrays (`EntryType`). The SDK
type definitions (typesafe-sdk-python, @typesafe-ai/sdk) are the authority for what the endpoint
accepts today; the API reference page is the narrower, older statement._

> "Every one of these fields is an `EntryType`" — `instructions` (all three types), Choice `criteria`
> values, Score `criteria` entries, and Noul `criteria.true`/`criteria.false` each accept
> `string`, `object`, `array`, or `null`.
> — https://docs.typesafe.ai/primitives/advanced.md

Use structure "When it helps with clarity" and "When question needs supporting data." A worked
Choice example uses per-option objects with `what`, `not_for`, and `examples` keys. Crucially:

> "The field names `question`, `focus`, `what`, `not_for`, and `examples` are not part of the API, and none are reserved. You choose them, the same way you choose option names. The model sees the names along with the values, so use short names that label what follows."
> — https://docs.typesafe.ai/primitives/choice.md

Score levels can be objects (`summary` + `signals`, or `what` + `examples`); Choice option values can
be whole subtrees of a taxonomy, which lets the model "see what lives under a branch before committing
to it" (https://docs.typesafe.ai/primitives/advanced.md).

## Question independence

> "Every answer is independent. One question's answer is not hidden context for another. You can add or remove questions without changing the others' results."
> — https://docs.typesafe.ai/primitives.md

> "Questions in the same request are independent: one answer does not become context for another question. If a later judgment depends on an earlier answer, make a second request in code. The dependency is real only when your code cannot build the second request until it has the first answer."
> — same page

## State formats

State is "the content you ask a System One model to evaluate." Accepted shapes
(https://docs.typesafe.ai/concepts/state.md):

| Format | Useful for | Example |
| --- | --- | --- |
| String | A message, article, or passage | `"My card was charged twice."` |
| Object | Named fields, related records, or application state | `{"message": "My card was charged twice.", "order_id": "A-104"}` |
| Array | A sequence of messages or records | `["Hi", "My customer number is TS1337.", "My card was charged twice."]` |

> "Use an object for most requests so each part of the state has a descriptive name and its relationships remain clear."

## Backtick path references

> "When a question is about one of those parts, name it in the `instructions` with a dot-and-index path to its key, including the backticks."
> — https://docs.typesafe.ai/primitives.md

```python
questions = {
    "refund_requested": {
        "type": "noul",
        "instructions": "Does `ticket.messages[0].text` request a refund?",
    },
    "policy_supports_refund": {
        "type": "noul",
        "instructions": (
            "Does `refund_policy` support the refund requested "
            "in `ticket.messages[0].text`, given `order.charges`?"
        ),
    },
}
```

The build guide repeats it: "include the backtick characters around each path inside the question...
such as `support.tickets[0].message`" (https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md).

## SDKs

**Python** (requires Python >= 3.10; `pip install typesafe-sdk` or `uv add typesafe-sdk`). The client
reads `TYPESAFE_API_KEY` from the environment and calls `jev-latest` by default.

```python
from typesafe_sdk import Choice, Noul, Score, TypeSafeClient

with TypeSafeClient() as client:
    response = client.system_one(
        state="I was charged twice. Please help ASAP.",
        questions={
            "billing": Noul(instructions="Is this about billing?"),
            "tone": Choice(instructions="What is the tone?", criteria={"calm": None, "angry": None}),
            "urgency": Score(instructions="How urgent is this?", criteria=["low", "medium", "high"]),
        },
    )
print(response.answers["billing"].noul)
```

`AsyncTypeSafeClient` is the async equivalent. Answers are reachable as `response.answers[id]` and
also as `response.nouls[id]`, `response.choices[id]`, `response.scores[id]`. A `response_model=`
argument accepts a pydantic model for extra type safety (v0.7.0).

Environment variables (https://docs.typesafe.ai/sdk/python/usage.md): `TYPESAFE_API_KEY` (required),
`TYPESAFE_BASE_URL` (default `https://api.typesafe.ai`), `TYPESAFE_DEFAULT_MODEL` (default
`jev-latest`), `TYPESAFE_LOG_LEVEL`.

**JavaScript / TypeScript** (Node.js 20 or newer; `npm install @typesafe-ai/sdk`):

```ts
import { choice, TypeSafeClient } from "@typesafe-ai/sdk";

const client = new TypeSafeClient();
const response = await client.systemOne({
  state: { document: "I was charged twice. Please fix this ASAP." },
  questions: { category: choice("What is this ticket about?", { billing: null, technical: null, other: null }) },
});
console.log(response.answers.category.choice);
```

"Answer types are inferred from your questions. The package includes ESM, CommonJS, and TypeScript
declarations." (https://docs.typesafe.ai/sdk/javascript.md)

## Errors

HTTP statuses, verbatim from https://docs.typesafe.ai/api.md:

| Status | Meaning |
| --- | --- |
| `401 Unauthorized` | Missing or invalid API key. Check the `Authorization` header. |
| `422 Unprocessable Entity` | The request body failed validation — for example a missing required field or a malformed question. The body details the offending field. |
| `429 Too Many Requests` | You have exceeded your rate limit. Back off and retry after a short delay. |
| `529 Overloaded` | TypeSafe is temporarily overloaded. Retry after a short delay. |

> "When you receive a `429 Too Many Requests` or `529 Overloaded` response, retry the request with exponential backoff instead of retrying immediately. Our client SDKs handle this automatically, so no extra handling is needed if you use one of our SDKs with its default retry policy."

Python exception classes: `TypeSafeError` (base), `TypeSafeAPIError` (with `.status`, `.body`,
`.headers`, `.endpoint`, `.request_id`), `TypeSafeAPIConnectionError`, `TypeSafeAPITimeoutError`,
`TypeSafeAPIResponseValidationError`, `TypeSafeAuthenticationError`, `TypeSafeBadRequestError`,
`TypeSafeInternalServerError`, `TypeSafeNotFoundError`, `TypeSafePermissionDeniedError`,
`TypeSafeRateLimitError`, `TypeSafeUnprocessableEntityError`
(https://docs.typesafe.ai/sdk/python/api/exceptions.md). The JS SDK mirrors these as `TypeSafeError`,
`APIError`, `APIConnectionError`, `APITimeoutError`, `APIUserAbortError`, `AuthenticationError`,
`BadRequestError`, `InternalServerError`, `NotFoundError`, `PermissionDeniedError`, `RateLimitError`,
`UnprocessableEntityError`.

## Retries (defaults)

Python `RetryPolicy` (https://docs.typesafe.ai/sdk/python/api/retries.md): `max_retries=2`,
`backoff_initial=0.5` s ("doubled each attempt up to `backoff_max`"), `backoff_max=5.0` s,
`backoff_jitter=0.25`, `http_statuses={408, 429, *range(500, 600)}`, `respect_retry_after=True`,
`api_connection_error=True`, `api_timeout_error=True`, `timeout=30.0` s.

JavaScript `RetryPolicy` (https://docs.typesafe.ai/sdk/javascript/api/interfaces/RetryPolicy.md):
`maxRetries` 2, `backoffInitialMs` 500, `backoffMaxMs` 5000, `backoffJitter` 0.25, `httpStatuses`
408, 429 and 500–599, `respectRetryAfter` true, `maxRetryAfterMs` 60000, `apiConnectionError` true,
`apiTimeoutError` true. Client `timeout` default is 10000 ms, "per attempt in milliseconds, without a
total retry budget" (https://docs.typesafe.ai/sdk/javascript/api/interfaces/TypeSafeClientConfig.md).

## v1 renames (for code written against the preview API)

`POST /preview/evaluation` → `POST /v1/systemone`; `prompts` array → `questions` map; `document` →
`state`; `responses` array → `answers` map; `probability` → `noul`; `chosen` → `choice`;
`expectation` → `score`; Choice `probabilities` array → map; Score `probabilities` new in v1;
confidence uses a new computation; `usage.billing_units` → `usage.input_tokens` /
`usage.output_tokens`; Python package `typesafe-client` → `typesafe-sdk`
(https://docs.typesafe.ai/migrating-to-v1.md).
