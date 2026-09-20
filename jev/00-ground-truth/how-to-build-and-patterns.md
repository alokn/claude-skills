---
id: gt-how-to-build-and-patterns
title: The design steps and the four official patterns
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (design steps, triage_ticket.py)
  - https://docs.typesafe.ai/patterns.md  (pattern index)
  - https://docs.typesafe.ai/patterns/fan-out.md  (speculative fan-out)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (confidence-gated routing)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (composite scoring)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (intent routing)
  - https://docs.typesafe.ai/primitives/score.md  (normalisation and weighting)
  - https://docs.typesafe.ai/demos/smart-home.md  (fan-out in a real demo)
---

## The stated summary

> "**Summary:** build a normal software workflow and insert System One only where AI is needed.
>
> * Keep control flow, deterministic rules, and side effects in code.
> * Break broad judgments into narrow, typed questions with explicit instructions and criteria.
> * Give each question only the context it needs.
> * Use probabilities and confidence to act, ask for review, or escalate.
> * Ask independent questions together, then compose their answers in code."
> — https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md

## The seven design steps

**1. Use code when you can.** "Keep deterministic work in code. It is reliable and cheap. Avoid agent
`while` loops when a software workflow can express the same behavior."

```python
days_overdue = (today - invoice.due_date).days

if days_overdue > 30:
    route_to_collections(invoice)
```

**2. Decompose the input state.** "Include only the context relevant to the current questions. This
helps the model avoid distractions and context rot. Do not rely on knowledge stored in model weights
when current information can come from your own knowledge base."

**3. Use structure in the input state.** "Use nested JSON for the `state` and `questions` fields.
Point questions at specific values when that removes ambiguity, and include the backtick characters
around each path inside the question." Example path: `support.tickets[0].message`.

**4. Decompose the questions.** "Ask the most explicit, narrow, specific, atomic questions you can.
Break down complex or ill-defined questions into separate questions that each evaluate one property."

> "This is probably the most important concept in this guide. Broad questions hide several judgments behind one answer. Atomic questions expose those judgments so you can inspect, tune, and combine them in code."

The page's worked contrast: one bad question `is_spam: "Is `message` spam?"` versus six good ones —
`requests_credentials`, `offers_unexpected_reward`, `creates_time_pressure`,
`sender_identity_mismatch`, `link_domain_mismatch`, `disguises_link_destination`, each pointed at a
named path in the state. A second contrast replaces `tool_calls_are_correct` with nine narrow checks
over a tool-call trace (tool relevance, argument/schema conformance, id matching, coordinate reuse,
date match, unit match).

**5. Use structure in the questions.** "Keep atomic questions short. When instructions or criteria
need several kinds of guidance, use objects or arrays with named fields instead of flattening
everything into a dense prose string... For a Choice, describe what belongs in each option, what
belongs in a neighboring option instead, and a few representative examples. Use the same field names
across options so the model can compare them directly."

**6. Ask a lot of questions.** "Ask many narrow, independent questions about the same state in one
request. This is how you maximize effectiveness and intelligence per dollar with the API: questions
run in parallel, and code can combine their signals without adding serial model round trips."

**7. Combine question outputs in code (or feed into a classical ML model).** "Combine independent
answers with deterministic rules or weighted sums. For learned composition, use the probabilities as
features in a downstream classical machine-learning model."

```python
answers = response.answers

# Combine independent signals into one application-specific score.
quality = (
    0.4 * answers["answers_request"].noul
    + 0.4 * answers["citations_are_supported"].noul
    + 0.2 * (1 - answers["contradicts_context"].noul)
)
```

**8. Route on uncertainty.** "Make code take different actions for confident and unconfident answers.
Escalate uncertain cases to a person or a more expensive reasoning model. Test thresholds by plotting
confidence against accuracy on your data."

```python
answer = response.answers["card_help_topic"]

if answer.confidence < 0.8:
    route_to_human_review(ticket)
else:
    route_to_handler(answer.choice, ticket)
```

> "Decomposition does not require more round trips. Questions over the same state run in parallel."

## The four patterns

| Pattern | What it does | Benefits |
| --- | --- | --- |
| Speculative Fan-Out | Send many questions in a single call, including speculative ones, and let your code decide what's relevant | Cost, Speed |
| Confidence-Gated Routing | Utilize confidence as a second decision axis to build safer systems | Reliability, Safety |
| Composite Scoring | Combine several dimensions of analysis into a single score | Cost, Reliability, Speed |
| Intent Routing | Classify a user's intent and route to the appropriate handler | Cost, Speed |

— https://docs.typesafe.ai/patterns.md

### Speculative fan-out

> "Because TypeSafe supports sending many questions in a single API call, we recommend putting all of the questions your system needs in a single request, and then using code to decide what is relevant after the fact. All questions are evaluated in parallel, so adding more questions to a call typically doesn't add any latency to the response."

> "**Speculative questions:** `bug_severity` and `has_reproducible_steps` only matter if the ticket is a bug report. `refund_requested` only matters for billing. We include all upfront because there is no speed cost for additional questions."

```python
category   = response.answers["category"]
bug_severity = response.answers["bug_severity"]
bug_repro  = response.answers["has_reproducible_steps"]
refund     = response.answers["refund_requested"]
frustration = response.answers["frustration"]

if category.choice == "bug_report":
    if bug_severity.score > 1.5 and bug_repro.noul > 0.6:
        escalate_to_engineering(ticket_id, severity="high")
    else:
        add_to_bug_backlog(ticket_id)
elif category.choice == "billing":
    if refund.noul > 0.7:
        route_to_billing_with_flag(ticket_id, refund_likely=True)
    else:
        route_to_billing(ticket_id)
elif category.choice == "feature_request":
    log_feature_request(ticket_id)

if frustration.score > 1.5:
    flag_for_priority_response(ticket_id)
```

Supporting number: "batching 13 questions into one call is 11.5x cheaper and 9.6x faster (the cookbook itself reports 12.2x / 10.0x for the same run) than 13
separate calls, with no change in the answers" (https://docs.typesafe.ai/primitives.md, citing the
Parallel questions cookbook). The smart-home demo applies the same pattern to request category, room,
device, and action (https://docs.typesafe.ai/demos/smart-home.md).

### Confidence-gated routing

> "Use confidence as a second axis. The answer tells you what; confidence tells you whether to act."

```python
action = response.answers["intent"]

# Below 0.6 confidence on any action, route to a human
if action.confidence < 0.6:
    route_to_support_agent(account_id)
elif action.choice == "check_balance":
    show_balance(account_id)
elif action.choice == "approve_transfer":
    if action.confidence > 0.85:
        approve_transfer(account_id)
    else:
        ask_user_to_confirm("Just to confirm: you would like to approve this transfer, is that correct?")
else:
    route_to_support_agent(account_id)
```

> "The 0.6 floor catches anything the model is genuinely uncertain about. Above that floor, each action type has its own threshold based on the consequences of acting on a wrong classification."

### Composite scoring

> "Break a complex judgment into atomic scores, combine with weights you control in code."

Resume screening with four independent five-level Scores (`python_depth`, `team_leadership`,
`system_design`, `generalist`), then:

```python
py      = response.answers["python_depth"].score / 4
lead    = response.answers["team_leadership"].score / 4
arch    = response.answers["system_design"].score / 4
general = response.answers["generalist"].score / 4

# Senior IC
ic_score = (0.40 * py) + (0.10 * lead) + (0.40 * arch) + (0.10 * general)

# Engineering Manager
em_score = (0.15 * py) + (0.40 * lead) + (0.20 * arch) + (0.25 * general)
```

> "it gives you visibility into how exactly the final score is being calculated. If the highest ranking candidates are not matching your expectations, you can adjust the weights to find the right balance."

Normalisation rule, from the Score page: "Divide each score by its top level number,
`len(criteria) - 1`, to put every score on 0 to 1. Then the weights mean what they say."
A worked triage example there produces `0.6 × 0.62 + 0.3 × 0.725 + 0.1 × 1.0 = 0.6895`.

### Intent routing

> "Classify incoming requests and route each to the optimal handler: deterministic logic, a specialist LLM, or a human."

```python
def route_ticket(ticket_id, response):
    intent = response.answers["intent"]
    complexity = response.answers["complexity"]

    if intent.confidence < 0.5:
        return route_to_human_agent(ticket_id)

    if intent.choice == "order_status":
        handle_order_status(ticket_id)
    elif intent.choice == "product_question":
        handle_with_llm(ticket_id, PRODUCT_SPECIALIST)
    elif intent.choice == "return_exchange":
        handle_with_llm(ticket_id, RETURNS_SPECIALIST)
    elif intent.choice == "complaint":
        low_confidence = complexity.confidence < 0.5
        if complexity.score > 1 or low_confidence:
            route_to_human_agent(ticket_id)
        else:
            handle_with_llm(ticket_id, COMPLAINT_RESOLUTION)
```

> "One intent routes to deterministic code with no LLM involved. Two route to different specialist LLMs, each loaded with different context. One uses the complexity score to decide between an LLM and a human. TypeSafe handles the classification all in a single quick call; the expensive resources only get invoked for the requests that actually need them."

## The full `triage_ticket.py` example

The canonical end-to-end example from
https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md. Question bodies use structured
`instructions` (`question` / `inspect` / `compare` / `focus`) and structured `criteria`
(`what` / `not_for` / `examples` / `signals`); reproduced below with the criteria bodies abridged for
length — the structure and the composition logic are the load-bearing parts.

```python
from typesafe_sdk import Choice, Noul, NoulCriteria, Score, TypeSafeClient


def triage_ticket(ticket, customer):
    # Handle deterministic states without calling a model.
    if ticket["status"] == "closed":
        return "no_action"

    open_orders = [
        order for order in customer["orders"] if order["status"] != "delivered"
    ]

    # Include only the structured context needed by the questions below.
    state = {
        "ticket": {
            "message": ticket["message"],
            "sender": ticket["sender"],
            "links": ticket["links"],
        },
        "customer": {"plan": customer["plan"], "open_orders": open_orders},
        "policy": {"sensitive_credentials": ["password", "security code", "API key"]},
    }

    # Ask structured, atomic questions together so they run in parallel.
    questions = {
        "topic": Choice(
            instructions={
                "question": "Which team should handle `ticket.message`?",
                "focus": "Classify the customer's primary request.",
            },
            criteria={
                "billing": {"what": "Charges, invoices, refunds, or subscriptions",
                            "not_for": "Order tracking or account access",
                            "examples": ["I was charged twice", "Where is my refund?"]},
                "orders":  {"what": "Order status, delivery, cancellation, or returns", ...},
                "account": {"what": "Login, profile, permissions, or security", ...},
            },
        ),
        "requests_credentials": Noul(
            instructions={
                "question": "Does the message request a sensitive credential?",
                "compare": ["`ticket.message`", "`policy.sensitive_credentials`"],
                "focus": "Look for a request to disclose the credential itself.",
            },
            criteria=NoulCriteria(true={...}, false={...}),
        ),
        "sender_identity_mismatch": Noul(...),   # display_name vs email domain
        "unexpected_reward": Noul(...),          # unsolicited prize/payment claim
        "refund_requested": Noul(...),           # explicit refund or credit request
        "mentions_open_order": Noul(...),        # message vs customer.open_orders
        "frustration": Score(
            instructions={
                "question": "How frustrated does the customer appear?",
                "inspect": "`ticket.message`",
                "focus": "Judge expressed frustration, not issue severity.",
            },
            criteria=[
                {"what": "Calm and matter-of-fact", "signals": [...]},
                {"what": "Frustrated but civil", "signals": [...]},
                {"what": "Very angry or threatening to leave", "signals": [...]},
            ],
        ),
    }

    with TypeSafeClient() as client:
        response = client.system_one(state=state, questions=questions)

    # Compose independent spam signals with weights controlled by code.
    answers = response.answers
    spam_risk = (
        0.45 * answers["requests_credentials"].noul
        + 0.30 * answers["sender_identity_mismatch"].noul
        + 0.25 * answers["unexpected_reward"].noul
    )

    # Escalate uncertain judgments instead of guessing.
    spam_is_uncertain = 0.4 < spam_risk < 0.6
    if spam_is_uncertain or answers["topic"].confidence < 0.75:
        return route_to_human_review(ticket)
    if spam_risk >= 0.6:
        return quarantine_as_spam(ticket)

    # Let code decide which speculative answers matter on this path.
    if answers["topic"].choice == "billing":
        return route_to_billing(ticket, refund_requested=answers["refund_requested"].noul >= 0.7)
    if answers["topic"].choice == "orders":
        return route_to_orders(ticket, mentions_open_order=answers["mentions_open_order"].noul >= 0.7)

    priority = (
        "high"
        if answers["frustration"].confidence >= 0.7 and answers["frustration"].score >= 1.5
        else "normal"
    )
    return route_to_account_support(ticket, priority=priority)
```

Every design step appears in it: a deterministic early return, a code-side filter building the state,
one request with seven atomic questions, code-owned weights, an explicit uncertain band
(`0.4 < spam_risk < 0.6`) plus a confidence gate on the routing Choice, and per-answer Noul
thresholds at 0.7.

## Where the pattern list stops

TypeSafe invites additions: "We're always keen to learn how people are making use of our primitives.
If you've found a killer use case you think should be mentioned here, feel free to drop us a note!"
(https://docs.typesafe.ai/patterns.md). Patterns beyond these four (beam search over a taxonomy,
two-stage rank-then-verify, shadow mode, downstream classical ML on jev probabilities) appear only in
cookbooks, not in the patterns section.
