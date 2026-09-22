---
id: gt-failure-modes
title: The nine jev-1.13 jaggedness failure modes
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (all nine failure modes, verbatim)
  - https://docs.typesafe.ai/primitives/score.md  (levels guidance referenced by mode 7)
  - https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md  (worked fix for mode 3)
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (worked fix for mode 5)
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (Choice vs Noul, mode 8)
---

TypeSafe publishes its own jagged-edges page for the current model. Header note, verbatim:

> "**Applies to `jev-1.13`.** Last reviewed 2026-09-17."

> "`jev-1.13` is fast, calibrated, and good at common-sense judgment but it is not perfect. `jev-1.13` does the best on System One tasks. It may struggle with tasks that require additional levels of indirection. It can be quite literal in its understanding. It struggles with tasks that require numeric precision."

The summary table, verbatim:

| # | Failure mode | Do this instead |
| - | --- | --- |
| 1 | Literal reading | Write the exact condition, criteria for each available options |
| 2 | Math and Numbers | Keep the arithmetic in code |
| 3 | Date and time comparison | Extract components; compare in code |
| 4 | Indirection | Reduce hops; point to the relevant state |
| 5 | Large state full of irrelevant detail | Filter first; send only what the question needs |
| 6 | Adversarial content | Write precise prompts, and test edge cases before deploying |
| 7 | Contradictory instructions and criteria | Align the criteria and instruction |
| 8 | Common-sense structural invariants | Ask each decision one way; enforce identities in code |
| 9 | Generation | Use a generative model |

---

## 1. Literal reading

> "`jev-1.13` answers the question you wrote, not the one you meant. Scoping words, negations, and implied conditions are read at face value. A question will be answered based on the words written in the instruction, whereas a person might have read the intent behind the instructions.
>
> **Instead:** state the exact condition in the `instructions`. Be specific. Put boundary cases in the criteria. When you look at a wrong answer and find yourself explaining what you really meant, that explanation is the missing half of the instruction. Where interpretation is unavoidable, split it into two literal questions and combine them in code."

**Recognise in a proposal:** the question text contains a word whose meaning the team would have to
argue about in review ("relevant", "serious", "appropriate", "properly") with no criteria pinning it down.

## 2. Math and numbers

> "Jev is not a calculator. We strongly recommend implementing any mathematical logic in code. Jev will perform better on semantic questions than mathematical ones."

### 2a. Counting

> "`jev-1.13` does not count reliably. This covers characters in a word, occurrences of a term in a passage, and items in a long list. The model recognizes the shape of an answer rather than tallying, and the error grows with the size of the thing being counted.
>
> Before asking a counting question, ask why the count needs a model at all. If the unit is something a regular expression or a parser can find, the count belongs in code and the model has nothing to add.
>
> **Instead:** count in code. When you want to count items matching some criteria, iterate in code over the candidates and ask one question for each, then add up the answers yourself."

The official code example, verbatim:

```python
from typesafe_sdk import Noul, TypeSafeClient

client = TypeSafeClient(model="jev-1.13")
YES = 0.5  # up to you on what you want the threshold to be, depends on your usecase.

items = ["typesafe", "apple", "california", "banana", "likes", "calibration", "orange", "vertex"]

result = client.system_one(
    {"items": items},
    {
        f"item_{i}": Noul(instructions=f"Is `items[{i}]` the name of a fruit?")
        for i in range(len(items))
    },
)

count = sum(result.nouls[f"item_{i}"].noul > YES for i in range(len(items)))
```

### 2b. Numeric representations

> "`jev-1.13` will perform better on semantic representations than numeric. For example, questions about colors using hex values will underperform compared to those using the English names. Given RGB triples or hex values it cannot reliably judge whether two values are near each other.
>
> Similarly, questions about high-level programming languages will perform better than questions about low level assembly, or binary encoded instructions.
>
> **Instead:** do the conversion in code and pass in either the computed number or a named bucket. Keep the model for the part that is genuinely a judgment, such as whether a color reads as a warning."

### 2c. Math using score

> "Please do not use score outputs (e.g., expectations and probability) to compute the exact magnitude of a number between two levels of a criterion. You can use the expectation to check if it passes a particular threshold, but `jev-1.13`'s score levels are weak in numerical calibration. It will not be able to help you reconstruct the exact number by interpolating between the nearest two levels."

**Recognise in a proposal:** any "how many", "what percentage", "sum", "average", "distance", or
hex/RGB/encoded-value comparison assigned to the model; or a design that reads a fractional `score`
as if it were a measured quantity rather than a position.

## 3. Date and time comparison

> "`jev-1.13` reads dates as text, not as ordered quantities. Asking which of two dates comes first, how far apart they are, or whether one falls inside a window is unreliable. It gets worse with mixed formats, relative references and domain boundaries such as quarters, settlement windows, and accrual periods.
>
> **Instead:** split the work. Extraction is a judgment, so give it to the model. Arithmetic is not, so keep it in code.
>
> Every part of a date is a small closed set: twelve months, thirty-one possible days, a bounded range of years. That turns extraction into a Choice over enumerated options rather than free-form parsing, and it gives you somewhere to put an explicit 'not stated' option so a missing part is reported rather than guessed. Code assembles the parts into a real date and owns everything after that, including ordering, duration, offset, and weekday."

Worked fix: https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md.

**Recognise in a proposal:** "is this overdue", "within the last 30 days", "which came first", "is it
in Q3", or any SLA/expiry/window check handed to the model.

## 4. Indirection

> "Instructions carrying double negatives or complex indirection are answered less reliably. A question about a property of a property or something that requires multiple hops of reasoning costs accuracy.
>
> **Instead:** write your instructions as directly as possible. When possible, identify the relevant parts of state by name."

**Recognise in a proposal:** the question needs two or more inferential hops ("does the policy that
governs the account that placed this order allow…"), or contains a negated condition inside another
condition.

## 5. Large state full of irrelevant detail

> "Accuracy falls as the state grows with content unrelated to the decision. Unrelated detail acts as a distractor, and a large state makes it harder to tell which part of the input produced a wrong answer.
>
> **Instead:** retrieve and filter in code first, and send only the fields the question needs. When it's not possible to filter in state, you can use a Noul to filter for relevance."

> "**Context length limit.** `jev-1.13` has a bounded context window. See the Models page for the exact token limits."

Worked fix: https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md.

**Recognise in a proposal:** the state is "the whole record", "the full thread", "the entire
document", or a dump of an API response, rather than a named subset built for these questions.

## 6. Adversarial content

> "State is data, and `jev-1.13` does not treat it as hostile by default. Content written to adversarially steer the model, whether that is an injected instruction, a deliberately misleading framing, or text that argues for its own classification, can move the answer. We expect to improve on this in the future.
>
> **Instead:** be explicit in the criteria. Test your integration thoroughly before deploying it to many users."

**Recognise in a proposal:** the state is attacker-controlled (user posts, inbound email, uploaded
documents, scraped web pages, LLM output being guardrailed) **and** jev is the only gate on the
action. Prompt-injection and jailbreak detection are listed as jev use cases, but jev alone is not a
hardened boundary.

## 7. Contradictory instructions and criteria

> "When the `instructions` and the `criteria` ask for different things, `jev-1.13` might get confused. The best performance comes from clear phrasing. For example, a Noul where `true` maps to no and `false` maps to yes will perform worse. Aim for instructions which are easy for the average person to read and understand.
>
> **Instead:** treat the criteria as an extension of the instruction. Align the two using clear and precise language."

**Recognise in a proposal:** an inverted Noul ("Is this NOT spam?"), a Score whose instructions say
"how good" while the levels run worst-to-best in the wrong direction, or Choice option descriptions
that overlap with each other or contradict the question stem.

## 8. Common-sense structural invariants

> "`jev-1.13` is extremely consistent, meaning you should expect quantitatively similar outputs for semantically similar inputs. However there are many structural invariants one might imagine to hold that simply aren't guaranteed by the model."

Noul vs yes/no Choice on "I'm not happy with the fit. What are my options here?":

| Noul `noul` | Choice `yes` | Choice `no` | Choice `confidence` |
| --- | --- | --- | --- |
| 0.22 | 0.01 | 0.99 | 0.97 |

A question and its negation as two Nouls on "I was charged twice for the same order. Can someone look
into this?":

| `refund` | `not_refund` | Sum |
| --- | --- | --- |
| 0.72 | 0.47 | 1.19 |

> "**Instead:** don't rely on expected structural invariance, and word questions to mean directly what you want. Don't carry a threshold tuned on a Noul over to a Choice, and don't hold the model to arithmetic identities between separate questions. A Choice over options and one Noul per option answer different questions: the Choice is relative, settling *which* option, while each Noul is absolute and can be low for all of them."

**Recognise in a proposal:** the design assumes `P(A) + P(not A) = 1`, reuses one threshold across
Noul and Choice answers, derives a "none of the above" from low Noul values, or compares probabilities
from two different questions as if they were on the same scale.

## 9. Generation

> "`jev-1.13` is not trained to generate text. While you can force it to by chaining choices, this will not work well and will be very slow. For data extraction, it is better to extract possible options using regex or a generative model and let `jev-1.13` pick the correct extraction.
>
> **Instead:** when the answer space is bounded, turn extraction into a Choice over the options rather than asking for the value itself. If you really need to generate text… there are other models for that."

**Recognise in a proposal:** the output is a string the user will read (summary, reply, title,
rewritten text, code), or an extraction where the candidate set is not enumerable up front.

---

## The "avoid the following" list, verbatim

> "**As a reminder, avoid the following:**
>
> * Asking the model something code can compute exactly.
> * Hiding several judgments inside one question.
> * System Two tasks: more layers of indirections
> * Giving it more context in `state` than the question needs. Jev suffers from context rot, so unrelated material in the `state` costs you accuracy."

Note the tension with the introduction page, which says questions in one request do not cause context
rot ("Each question is evaluated independently, so adding more questions does not create
context-rot", https://docs.typesafe.ai/introduction.md). The jaggedness page's context-rot warning is
about **state size**, not question count. Both can be true: many questions are cheap, a bloated state
is not.

## Reporting

> "Found a failure mode that belongs on this list? We want to hear about it. Reach us on Discord."
> — https://discord.com/invite/WUujKYBp8s
