---
id: uc-sdlc-pre-commit-diff-screening
title: Screen a staged diff in a local pre-commit or pre-push hook
verdict: good
domain: sdlc
decision_shapes: [detection, verification, classification]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/AkashPriyadarshii/jev-git  (pre-commit / pre-push diff screening; no accuracy numbers published)
  - https://github.com/valentynkit/jev-commit  (message-to-diff alignment; "blocks only on credential detection")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 2 arithmetic)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-sdlc-pr-title-matches-diff, uc-sdlc-semantic-lint-team-conventions, uc-trust-safety-pii-exposure-detection, au-sole-security-gate, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev in a pre-commit hook?" Also: "can jev stop me committing a
secret?", "can it tell me my commit message does not describe the diff?", "we already run
gitleaks — what would jev add?".

## Verdict

**Good**, with one structural rule that is not optional: of the several questions you ask,
**at most one is allowed to block**, and the deterministic secret scanner stays authoritative
and runs first. The two public implementations take exactly this shape — one screens the
staged diff at commit and push time, the other checks message-to-diff alignment and "blocks
only on credential detection". Neither publishes an accuracy figure, which is why this is
`good` and not `strong`. What jev adds over the regex pass is the secret that is *shaped*
like a credential without matching a known pattern: a bare internal hostname with a password
in the URL, a base64 blob assigned to `AUTH`, a customer record pasted into a fixture.

## What jev decides

Filter in code before the call. Send the staged diff **truncated to added lines only**, plus
the commit message and branch name. A whole-repo or whole-history state is the fastest way to
hit jaggedness mode 5.

```
secret_present: Noul
  instructions: "Do the added lines contain a credential, token, private key or connection
                 string with a real-looking value?"
  true:  "An added line embeds or assigns a value that looks live: a long opaque token, a
          private key block, a URL carrying a password, a hard-coded API key."
  false: "Placeholders and obvious fakes (`xxx`, `changeme`, `sk-test-...`), values read from
          the environment or a secret manager, or a documented example credential."
debug_artefact_left: Noul
  instructions: "Do the added lines leave debugging scaffolding behind — a print/console
                 statement, a commented-out block, a skipped test, a hard-coded local URL?"
unrelated_change_bundled: Noul
  instructions: "Do the added lines contain a change unrelated to what the commit message
                 describes?"
message_matches_diff: Noul
  instructions: "Does the commit message describe what these added lines actually do?"
```

`secret_present` above a threshold you fitted on your own history blocks and prints the line.
Everything else prints a warning and exits zero. Below the threshold: today's behaviour,
unchanged. The hook must be bypassable (`--no-verify` plus an env flag) and must **exit zero
on a network error or timeout** — a commit hook that fails closed on someone's train wifi
will be deleted within a week.

## What stays in code

The gitleaks/trufflehog pass and the entropy check, run first and short-circuiting before any
network call. Diff extraction, added-line filtering, truncation, and the exclusion list
(lockfiles, vendored directories, binaries, generated code). File and line counts — that is
arithmetic, jaggedness mode 2. The timeout, the bypass, the exit code, and the allowlist of
known-fake fixture values.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 6,000-character
added-line diff plus the message plus four questions with criteria (~2,500 characters) is about
2,125 tokens, **≈ $0.000089 per commit**. The four questions ride in one call, so the latency
is one round trip: the models page gives "70 to 500 ms, most queries about 100 ms" — which is
the budget that matters here, because a human is waiting at the terminal.
**No accuracy number is published by either implementation.** Labelled data is available for
free from your own history: every secret your scanner has ever caught, plus every commit that
was later reverted for bundling unrelated work.

## When the verdict flips

- **Anything besides the secret question blocks.** Then it is a gate, and the corpus position
  on sole gates applies.
- **The hook is your only secret defence.** Then it is `no`: keep server-side push protection.
- **You send whole files or the full repository.** Mode 5, and the diff will not fit a 32k state.
- **Your diffs are mostly generated or vendored.** Noise, cost and no signal; exclude them.
- **The network call fails closed.** A blocked commit on a flaky connection is a worse bug
  than the one you were catching.

## Alternatives considered

- **gitleaks / trufflehog / detect-secrets.** Free, offline, exact on known patterns, and they
  stay. Blind to a secret that matches no pattern.
- **Entropy thresholds.** Cheap and catch some unpatterned tokens; noisy on hashes and minified
  code.
- **Server-side push protection.** The real safety net, and not a substitute for local feedback.
- **Frontier LLM in the hook.** Explains the finding well; seconds of latency at the terminal
  and cents per commit is the wrong shape for a hook.
- **Code review.** Catches the bundled-change and message problems, hours later.

## Sources

- https://github.com/AkashPriyadarshii/jev-git — accessed 2026-09-19
- https://github.com/valentynkit/jev-commit — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
