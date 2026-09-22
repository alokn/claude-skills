---
id: cb-classification_using_confidence
title: Classification using confidence
url: https://docs.typesafe.ai/cookbooks/classification_using_confidence.md
decision_shapes: [classification, routing]
primitives: [choice]
related: [uc-search-retrieval-confidence-fallback-broader-level, uc-legal-compliance-document-type-classification, au-confidence-as-correctness-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Classify SEC annual reports into 75 SIC industry groups with one `Choice` question per
document, then read the answer's own `confidence` to decide whether to report the narrow
industry group or the broader division above it.

Datasets:

- `sic_codes.tsv`, "the industry list the SEC publishes for filers to pick their own code
  from, fetched 2026-08-10: 444 four-digit codes, each with an industry title." Printed as
  "444 industries -> 75 major groups -> 10 divisions". Groups run "from `01` agricultural
  production to `99` non-classifiable"; the ten divisions are fixed ranges of major groups.
- `filings.jsonl`, "60 annual reports (10-K), each trimmed to Item 1 'Business'". "They
  span 1993–2024 and run from 700 to 2,200 words"; printed as "60 filings, 1438 words on
  average". Each carries the SIC code its filer chose plus an EDGAR accession number.

"Numbers below came from `jev-1.12` on 2026-08-12."

## Decomposition (state, questions, how answers are combined)

State is the raw Item 1 text: `client.system_one(state=text, questions=questions(),
model=TYPESAFE_MODEL)`.

One question, 75 options, one request per document:

```python
QUESTION = (
    "Which broad industry does this company operate in? Judge the company's own operations "
    "as this filing describes them."
)
Choice(instructions=QUESTION, criteria={group: describe(group) for group in sorted(GROUPS)})
```

Each option's description is built from the taxonomy file with no model involved:
`describe(group)` returns `f"{umbrella} — includes: {listed}"` with up to `MAX_NAMED = 8`
industries listed, because "a group's own name is not always there: 42 of the 75 carry an
umbrella title in the SEC's list, and the rest carry none." Example output: "group 20: food
and kindred products — includes: meat packing plants; sausages & other prepared meat
products; ...".

The answer returns `choice`, `probabilities` over all 75, and `confidence`. The recipe
reads `confidence`, not the winner's probability: "A winner at 0.45 with a runner-up at
0.44, and a winner at 0.45 with the rest of the weight scattered thinly, are different
situations, and `confidence` is what separates them."

Confidence band and the low-confidence path — a single cutoff, two bands:

```python
CONFIDENT = 0.9  # above this the group is reported; below it, the division

def classify(filing: dict) -> dict:
    answer = ask(filing["id"], filing["text"])
    sure = answer["confidence"] >= CONFIDENT
    return {
        "level": "group" if sure else "division",
        "label": answer["group"] if sure else division(answer["group"]),
        ...
    }
```

There is no abstain and no second call: "Every filing still comes back with a usable label.
One the model could not classify confidently comes back one level up instead of being
dropped or sent on." The broad label is derived from the narrow one by integer range lookup
over `DIVISIONS`, so the coarse answer is free. Scoring uses `filing["sic"][:2]` as gold at
group level and `division(gold_group)` at division level.

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run: `jev-1.12`, 2026-08-12. Setup: 75 industry groups, 10 divisions, 444 industries, 60
filings, one request per document. "a Choice works reliably up to roughly 240 options, and
75 is well inside that."

Band split at `confidence >= 0.9` — "a confidence cutoff of 0.9 splits them in half":

| Band | n | Group named every time | Broader answer when unsure |
| --- | --- | --- | --- |
| confident (`conf >= 0.9`) | 30 | 27/30 right | group reported, unchanged |
| unsure (`conf < 0.9`) | 30 | 12/30 right | reported as division |
| all | 60 | 39/60 right | 48/60 useful answers |

Verbatim from the output block:

```
forced to name a group every time      39/60 right
  of those, the 30 it was sure about  27/30 right
  and the 30 it was not           12/30 right

letting it answer coarsely when unsure  48/60 useful answers
```

Verbatim from the prose: "The confident half is right 90% of the time; the other half,
40%. Reported one level up, that 40% becomes 70%." And: "Where the model was sure, the
group it named is right nine times in ten. Where it was not, naming a group was wrong more
often than right, at 40%. Reporting those same answers as a division takes them to 70%."

Individual confidences shown: three filings at `conf 1.00` (`310158_1996` group 28
chemicals & allied products; `33416_1998` group 63; `352541_1996` group 49) and three low
ones — `1372167_2013` at `conf 0.22` (-> division manufacturing), `1398633_2009` at
`conf 0.23` (-> division wholesale trade), `46653_1999` at `conf 0.29` (-> division
services).

Cost: not reported. Latency: not reported. Token counts: not reported. Repeats
(`NUM_SAMPLES`): not reported. Standard deviations: not reported. No comparison against any
named LLM is made; the comparison is between two policies over the same answers.

## Caveats the cookbook itself states

- The gold label is self-reported: "whoever prepared the filing picked it once, and it goes
  stale when a company sells the business the code names and keeps the code."
- The sample is filtered, and the cookbook says so before quoting any accuracy: "These 60
  were filtered down to filings whose own text supports the code they carry, so the numbers
  here measure the recipe rather than the state of EDGAR's metadata."
- Sixty filings only, one request each; the confidence split happens to land at 30/30.
- The coarse answer may not be good enough: "If a division is too coarse for your
  application to act on, this branch is where you hand it to a person."
- The recipe depends on the label space having a roll-up. The broader answer is only free
  because "SIC labels form a hierarchy" and "The broad label follows from the narrow one".
- The option-count guidance is approximate — "roughly 240 options".

## Lessons transferable to other use cases

- Confidence bands with a coarse fallback: instead of abstaining or escalating, answer at a
  less specific level of the taxonomy when confidence is low.
- Read `confidence` rather than the winning option's probability; they answer different
  questions about the same distribution.
- The hierarchy roll-up makes the degraded answer cost zero extra calls — this only
  transfers to label spaces with a genuine parent level.
- Build option descriptions from the taxonomy source, not by hand: 42 of the 75 groups carry an
  umbrella title in the SEC's list and the remaining 33 carry none, so every option is described
  by the industries it contains rather than relying on a name that may not exist.
- Triage is normally the expensive part ("a second model, extra calls, human review") and
  here it is one number already in the response.
- What does not generalise: the 0.9 cutoff and the 90% / 40% / 70% figures belong to this
  task, this taxonomy and these 60 filtered filings.

## Use-case entries this supports

- `uc-search-retrieval-confidence-fallback-broader-level` — answer at a coarser taxonomy level when the narrow classification is not confident
- `uc-legal-compliance-document-type-classification` — classify an inbound filing or legal document by type, with a coarser answer when unsure

**Anti-use-case implied:** `au-confidence-as-correctness-gate` — the confidence fallback buys
nothing where labels have no parent level to roll up into, and confidence alone is not a
correctness gate; a division-level answer too coarse to act on is the hand-off point to a person,
which the cookbook marks explicitly.
