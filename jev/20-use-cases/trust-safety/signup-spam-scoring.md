---
id: uc-trust-safety-signup-spam-scoring
title: Score a new account signup for spam from the registration metadata you already store
verdict: good
domain: trust-safety
decision_shapes: [scoring, detection, classification]
primitives: [score, noul, choice]
evidence_level: community-report
sources:
  - https://github.com/Nishfleet/0509/issues/3542  (signup spam probability on the signup handler write path; advisory until 100 logged rows; "$0.042/MTok", "~600 ms", "$1 per packet" spend cap)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6 adversarial content can move the answer; mode 5 context rot)
related: [uc-trust-safety-spam-phishing-atomic-signals, uc-trust-safety-user-report-triage, uc-observability-evals-confidence-threshold-calibration-fitting, au-sole-security-gate, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to filter spam signups?" Also: "our disposable-email blocklist
is always a week behind — can a model read the registration form instead?", "can we score new
accounts at creation rather than after they post?", "can jev replace our signup heuristics?"

## Verdict

**Good.** A public deployment specifies exactly this decision — a spam probability computed
in the signup handler write path, "advisory then enforced after 100 logged rows"
(github.com/Nishfleet/0509/issues/3542). The shape fits: the input is short text you already
have, the output is one probability, and the enforced action is reversible (a review queue,
not a ban). It is `good` rather than `strong` because that deployment publishes a design, a
latency and a cost — "~600 ms", "$0.042/MTok", a "$1 per packet" spend cap — and no accuracy
result. Note what this entry is *not*: message-content spam and phishing, which has a
measured independent benchmark, lives in `uc-trust-safety-spam-phishing-atomic-signals`.
Here there is no message yet, only a registration record.

## What jev decides

State is the registration row, nothing more: `email_local_part`, `email_domain`,
`display_name`, `referrer`, `self_described_reason` (the "why are you signing up" field),
`bio`, and the account's declared organisation. Do not put the IP, the timestamp, or any
counter in the state — those are code's job and mode 2/3 territory.

```
spam_probability: Score
  instructions: {question: "How likely is it that this registration is being made to
                            send spam, scrape, or abuse the service rather than to use it?",
                 focus: "Judge the text the person wrote. Do not judge the email provider."}
  criteria: ["Reads like a person describing a real need in their own words.",
             "Generic but plausible; nothing written that a bot could not have written.",
             "Marketing copy, link bait, keyword stuffing, or a reason that does not match
              the product at all."]

name_is_generated: Noul
  instructions: "Does `display_name` look machine-generated (random characters, a
                 name-plus-digits pattern, or an unrelated brand) rather than a name a
                 person uses?"

bio_promotes_something: Noul
  instructions: "Does `bio` or `self_described_reason` promote an unrelated product,
                 service or URL?"
```

Three questions, one call, one latency. Bands: above your fitted upper threshold, hold the
account for review; below your fitted lower threshold, admit as today; in between, admit and
log. The low-confidence path is always today's behaviour — never a block.

Closest jaggedness mode: **6, adversarial content can move the answer.** The person filling in
the form knows there is a filter. Design for it by keeping the enforced action reversible and
by leaving the deterministic signals authoritative.

## What stays in code

Everything with a definite answer, and it runs *first*: disposable-domain and blocklist
lookups, MX validity, IP and ASN reputation, rate limits per IP and per subnet, duplicate
device fingerprints, invite-code validity, and the CAPTCHA result. If any of those fires, act
on it and skip the call — jev only scores the residue that survives them. Also in code: the
write itself, the review-queue insert, the audit row, the spend cap, and the flag that
switches advisory to enforced.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A registration
record of ~600 characters plus three questions with criteria (~1,400 characters) is about
500 tokens, **≈ $0.000021 per signup**. Field evidence from the public deployment:
"~600 ms" per call, "$0.042/MTok" input with free output, and a "$1 per packet" spend cap as
the circuit breaker (github.com/Nishfleet/0509/issues/3542, 2026-09). The same source sets
the flip rule: advisory until 100 rows are logged. No accuracy figure has been published for
signup spam by anyone, including that deployment — treat the first 100 rows as the only
number that applies to you.

Labelled data is free and arrives on its own: every account you later ban, and every account
that is still active and paying in 90 days. Fit the two thresholds against that, per the
calibration workflow entry.

## When the verdict flips

- **Your blocklists already catch nearly everything.** Measure the residue first. If
  deterministic signals handle 99% of signup spam, this is **weak**.
- **The signup form has no free text.** With only an email address and a password there is
  nothing for a language model to read; the decision is entirely lookups and rates.
- **You want to hard-block at signup.** A false block is a lost customer with no recourse and
  no explanation — jev cannot give one. Route to review instead, or the verdict is **no**.
- **Signups are multilingual and unevaluated.** See `au-non-english-at-scale-unevaluated`.
- **Signup volume is a handful per day.** The economics disappear; a human reads them.

## Alternatives considered

- **Blocklists, rate limits, IP reputation.** The incumbent and still the first line. Exact,
  free, and blind to a well-formed registration from a clean IP.
- **CAPTCHA / proof of work.** Stops automation, not paid humans; orthogonal, keep it.
- **Fine-tuned classifier on your own signup history.** The likely long-run winner once you
  have a few thousand labelled accounts, which you will have from the shadow log. Compare it.
- **Frontier LLM.** Can explain its reasoning in the review queue, which jev cannot; seconds
  and cents per signup on a write path that must stay fast.
- **Post-hoc detection (ban after first spam post).** What most teams actually do. Cheaper
  and better-evidenced, but the spam has already been sent. Run both.
- **Human review of every signup.** Correct for tiny volume; that is the case where this
  entry does not apply.

## Sources

- https://github.com/Nishfleet/0509/issues/3542 — accessed 2026-09-19 (signup-handler
  integration point, advisory-then-enforced after 100 logged rows, "$0.042/MTok", "~600 ms",
  "$1 per packet" spend cap)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
