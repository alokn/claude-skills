---
id: uc-sdlc-malicious-package-screening
title: Score whether a new dependency looks malicious, to order a human review queue
verdict: conditional
domain: sdlc
decision_shapes: [detection, scoring, classification]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://github.com/luantak/is-malicious  (supply-chain "is this package malicious" screening; no numbers published)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 6: adversarial content can move the answer)
  - https://github.com/jon-devlapaz/jev-me/issues/7  (unpinned upstream fetch in the official skill; supply-chain risk)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sdlc-dependency-alert-triage, uc-trust-safety-security-alert-triage-pipeline, au-sole-security-gate, uc-agents-harness-prompt-injection-semantic-flag]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect malicious npm/PyPI packages?" Also: "can jev catch a
typosquat before it lands in our lockfile?", "can we screen every new transitive dependency?",
"can jev replace our supply-chain scanner?".

## Verdict

**Conditional.** The condition: jev **orders a human review queue and blocks nothing**. The
public implementation screens package metadata and install scripts and is shipped as a
screening tool, not a gate; it publishes no accuracy numbers. The reason the condition is
absolute rather than cautious is jaggedness mode 6 — *adversarial content can move the
answer* — and here the adversary literally writes the input. A malicious package author
controls the README, the description, the keywords and the install script, and can therefore
write text aimed at your classifier. A screening signal an attacker can author must never be
the thing that decides.

## What jev decides

State, assembled in code from the registry API and the tarball: package name, the names of
your existing direct dependencies (for the typosquat question), version, age in days,
maintainer count, whether an install/postinstall script exists and its text, the network and
filesystem APIs the entry point imports, and the README first 2,000 characters. Do not send
the whole tarball — mode 5.

```
install_script_does_network_or_fs_work: Noul
  instructions: "Does the install script fetch from the network, write outside the package
                 directory, read environment variables, or spawn a shell?"
  false: "It compiles, links, or prints. It touches nothing outside the package directory."
name_impersonates_known_package: Noul
  instructions: "Is `package_name` shaped to be mistaken for one of `known_dependencies`?"
  true:  "A transposition, an added or dropped hyphen, a scope swap, a homoglyph, or a
          plausible-sounding namespace of a well-known project."
  false: "A distinct name that merely shares a common word."
description_does_not_match_code: Noul
  instructions: "Does the README describe functionality the entry point does not import
                 the capabilities for?"
obfuscation_present: Noul
  instructions: "Does the entry point contain long encoded blobs, dynamic eval, or
                 character-code string assembly?"
review_priority: Score
  criteria: ["Routine new dependency.", "Worth a look this week.", "Look before it merges."]
```

Code sums the flags into a queue order. High band: the PR carrying the dependency gets a
comment and a required reviewer. Low band: nothing changes.

## What stays in code

Everything deterministic and everything authoritative: lockfile pinning and integrity hashes,
registry signature and provenance attestation, known-CVE and known-malware advisory lookups,
exact typosquat edit distance against your own dependency names, package age and download
counts (arithmetic — mode 2), maintainer-change detection, and the allow/deny list. The
sandbox that actually prevents an install script from running. Tarball extraction and the
size cap.

## Numbers

**No accuracy, precision or recall figure is published** for this task by any source in the
corpus. Cost only, by method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`,
output free. A state of ~6,000 characters (metadata, install script, imports, README head)
plus five questions with criteria (~3,000 characters) is about 2,250 tokens, **≈ $0.000095
per package version**. Screening is per new *version*, cached by integrity hash, so the
volume is your dependency churn, not your build count. Labelled data for calibration exists
publicly: the published malicious-package advisories for your ecosystem, against a sample of
your current dependency set as negatives.

Note a related finding about the tooling itself rather than the decision: the official jev
skill was flagged for instructing agents to fetch an unpinned `main`-branch file from an
upstream repository before the first call. A supply-chain screener that has its own
supply-chain problem is worth pinning.

## When the verdict flips

- **It blocks a build or auto-rejects a dependency.** Then it is `no` — a sole security gate
  whose input the attacker writes.
- **You screen every transitive dependency on every CI run.** Cache by hash or the cost is
  real and the signal is unchanged.
- **Your ecosystem has no install scripts and strong provenance** (signed, reproducible,
  vendored). The deterministic checks already win.
- **You have no reviewer for the queue.** A priority order nobody reads is worse than nothing,
  because it feels like coverage.

## Alternatives considered

- **Registry advisories / OSV / Dependabot.** Authoritative for *known* bad packages and free;
  by construction blind to the one uploaded an hour ago. Keep them first.
- **Typosquat edit distance in code.** Exact, free, and better than jev at the pure-string
  question; jev adds the semantic impersonation (a plausible namespace, not a near-miss spelling).
- **Static analysis / sandboxed install (Socket, Phylum, packj).** The real competitor and
  usually the better buy: they observe behaviour rather than read prose.
- **Frontier LLM.** Can explain the finding to the reviewer, which matters here; too slow and
  costly for every version, so use it on the top of the queue jev ordered.
- **Human review of every new dependency.** The thing being prioritised, not replaced.

## Sources

- https://github.com/luantak/is-malicious — accessed 2026-09-19
- https://github.com/jon-devlapaz/jev-me/issues/7 — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
