# Detection signals: what in a codebase indicates a jev opportunity

Contents: How to use · A) Replace existing logic · B) New product features · C) SDLC and dev workflow ·
Counter-signals (when to say no) · Grep cheatsheet

## How to use

Each row is a **candidate**, not a finding. A finding requires: reading the code, confirming the
mechanism, citing `file:line` with a verbatim snippet, and passing the fit test in `fit-rubric.md`.
The `scripts/orient.sh` output tells you which signals fire in this repo and in which files; start there.

Category codes match the report: **A = replace**, **B = feature**, **C = sdlc**.

## A) Replace existing logic (more accurate, faster, cheaper)

| Signal in code | Why it is a jev opportunity | Jev shape | Closest cookbook |
|---|---|---|---|
| LLM call whose prompt asks for a label, yes/no, 1-5 rating, or JSON with only enum/bool fields (`max_tokens` small, "answer with only", `.strip().lower()` on the completion, `json.loads` in a retry loop) | Same decision at ~100 ms, $0.042/Mtok input, output free, schema cannot be violated, calibrated confidence instead of overconfident text | Choice / Noul / Score. Fan out every question in the prompt into one call | `parallel_questions`, `function_calling` |
| Typed-output LLM libs where the schema is *entirely* enum / bool / bounded int (Instructor `response_model`, Vercel `generateObject` with `z.enum`, Outlines `choice`, BAML, `response_format: json_schema`) | Modelling already done; backend swap is small. Strongest "replace" signal | Choice per enum field, Noul per bool | `function_calling`, `sde_cascade` |
| LLM used as router: picks a model, tool, skill, agent, or handler | Routing is the canonical System One task; cheap enough to run on every request | Choice with `other`; Score for difficulty tier; confidence gate to escalate | `skill_suggestion`, `intent-routing` pattern |
| LLM-as-judge in evals, guardrails, output validation, tool-call checking | Judges drift run to run; jev per-question stdev ~0.01; 100x cheaper so you can judge everything, not a sample | One Noul per check; Choice for "does context support claim" | `citation_check`, `classifying_rag_passages`, `consistency_*` |
| Free-text LLM generation whose *only consumer* is a downstream `if` (e.g. "summarise then check if it mentions X") | The generation step is waste; ask the question directly | Noul / Choice on the raw text | how-to-build guide |
| Keyword / pattern lists used as rules (`KEYWORDS = [...]`, `SPAM_WORDS`, `if any(w in text for w in ...)`) | Brittle, no confidence, endless maintenance, ordering bugs; semantics beat lexical lists once meaning matters | One Noul per property the list is proxying for (urgency, refund request, spam) | `pre_parsed_value_extraction_cookbook` for the hybrid |
| `if/elif` or `switch` chains on string content (`text.includes("refund")`, `subject.lower().startswith`) | Same as above; each branch is a hidden label | Choice over the branch labels + `none` | `intent-routing` |
| Regex whose match *is a label* (`/error|fail|timeout/` -> "failure") rather than an extraction | Regex is right for structure, wrong for meaning; evaluations often expose latent regex bugs | Noul / Choice; keep regex for extraction of candidates | `pre_parsed_value_extraction_cookbook` |
| Regex or parser pulling dates, amounts, ids from prose with many edge-case branches | Jev cannot do date math, but it can *select* the right candidate the parser found | Choice over code-produced candidates; date parts as Choice over enumerated components | `date_extraction_cookbook` |
| Embedding cosine threshold used to classify, dedupe, or route (`similarity > 0.8`) | Threshold tuning replaces judgement; jev answers "same thing?" directly with a probability | Noul per candidate pair; Score merge / leave / review | KG entity alignment (official skill), `rerank_typesafe` |
| Fuzzy string matching for entity dedup (levenshtein, rapidfuzz, difflib, fuse.js) | False merges on near-strings; misses on semantically-equal different strings | Code shortlists by fuzzy score, jev judges the shortlist | KG entity alignment |
| Search results returned in BM25 / ILIKE / tsvector / `ORDER BY created_at` order with no rerank | Rerank top-k with one question per (query, candidate) in a single call | Score relevance per candidate; Noul "does any candidate answer it" | `rerank_typesafe`, `semantic_find` |
| Sentiment / language / toxicity library with a fixed taxonomy | Your own criteria, calibrated, in your domain's vocabulary | Score or Noul with your rubric | `consistency_choice_cookbook` (moderation) |
| Manual review, moderation, approval, or triage queue with no automated pre-score (`needs_review`, `reviewed_by`, `pending`, admin list of unlabelled items) | Humans see everything; jev pre-scores, high confidence auto-actions, only the uncertain band reaches a human. Past decisions in the DB are a free eval set | Choice/Score + three confidence bands | `consistency_noul_cookbook`, `confidence-routing` pattern |
| Rule engine / automation rules whose conditions are string `contains` | Add a semantic condition type backed by jev | Noul per condition | `intent-routing` |
| Static tier / risk / priority assignment by table lookup on a category field | The category was itself a proxy for a judgement | Score on the underlying dimension | `composite-scoring` pattern |

## B) New features (value the product does not deliver today)

Look for **unstructured text flowing through the product with no judgement applied**. Free-text model fields
(`description`, `body`, `comment`, `message`, `notes`, `title`), inbound channels (webhooks, email intake,
forms, imports), and lists users scan by hand.

| Product surface | Feature jev enables | Jev shape | Why jev specifically |
|---|---|---|---|
| Items created by users/customers (tickets, issues, posts, listings, leads, claims, applications) | Auto-triage on create: type, team/queue, priority, severity, needs-more-info; **suggested** in the UI with confidence, auto-applied above a threshold | Speculative fan-out: Choice for type/queue, Score for severity, Noul for "has repro steps" etc. | 100 ms lets it run synchronously in the create path |
| Same items, with existing "duplicate" / "related" relations maintained manually | Duplicate detection on create: code shortlists by search, jev judges each candidate pair | Noul "same underlying issue?" per candidate; Score merge / link / ignore | Cheap enough to judge 20-50 candidates per new item |
| `tags`, `labels`, `category`, `assignee`, `priority` fields that are nullable and mostly empty | Smart defaults / auto-tagging with confidence-gated suggestions | One Noul per label (multi-label) or Choice for single field | Suggest at 0.6, auto-apply at 0.9 |
| Free-text field edited in a form (debounced input) | Inline quality checks as the user types: "is the description actionable?", "does it include reproduction steps?", "tone" | Noul / Score | Sub-500 ms fits keystroke-driven UI |
| Notification, digest, alert, or activity feed | Attention gating: "does this comment need the recipient's action?", bundle low-importance into digests | Score importance; Noul needs_action | Runs per event at negligible cost |
| Search, list, or feed sorted by recency | Semantic rerank of top-k; "sort by relevance" that means it | Score relevance per candidate | Validate: reranking is not a free win over good vector retrieval |
| Import / migration / sync of external records (CSV, Jira, GitHub, Salesforce) | Map external states/types/labels onto internal schema per row; flag low-confidence rows | Choice over internal options + `other` | Map-reduce over thousands of rows for cents |
| Community / public content (comments, reviews, public boards, intake forms) | Moderation with your policy: allow / warn / review / block by severity x confidence | Noul per policy dimension; Score severity | Deterministic bands in code |
| Existing AI feature (assistant, rephrase, summary, autocomplete) | Guardrail the AI: verify output before showing (on-topic? contradicts source? unsafe? tone matches request?) | Noul per check, on (input, output) state | Universal verification at a fraction of the LLM's cost |
| Multi-step form or onboarding with free text ("what do you want to do?") | Intent routing to the right template / workflow / plan | Choice + confidence gate | `intent-routing` |
| Historical labelled outcomes (churned, converted, escalated, refunded) alongside free text | Semantic features for a classical model: intent, frustration, competitor mention, blocker | Score / Noul features -> CatBoost/logistic | `autoresearch_feature_discovery` |
| Knowledge base, docs, help centre | "Does this doc answer the question?" before invoking an LLM; select relevant sections | Noul + Choice over section ids | `semantic_find`, `classifying_rag_passages` |

Feature ideas must name the **user** who benefits, the **moment** in the product where it fires, and what
happens at **low confidence**. A feature with no low-confidence path is not designed yet.

## C) SDLC and developer workflow

| Signal in repo | Opportunity | Jev shape | Notes |
|---|---|---|---|
| `.github/workflows` with lint/build only; PR template with checklists | Semantic PR lint in CI: does the description explain *why*; does the diff match the title; is each checklist item satisfied; does it touch risky areas (auth, billing, migrations) beyond path globs | Noul per check on (title, body, diff summary) state; Score risk | Advisory comment first, gate later. Budget: chunk diffs; deterministic checks first |
| `CODEOWNERS`, `labeler.yml`, title-regex label bots | Reviewer routing and labelling by *meaning* of the change, not paths | Choice over teams/labels + `other` | Keep CODEOWNERS as authority; jev suggests |
| Issue templates, public issue tracker, `intake` | Issue triage bot: bug / feature / question / support; needs-repro; duplicate of open issue; area label | Fan-out Choice + Nouls | Same primitives as product intake triage |
| Retry configs, `flaky` markers, `rerun-failed`, log greps deciding rerun | CI failure triage: infrastructure / flaky / real regression / dependency, before auto-rerun | Choice on the failure excerpt + Noul "same failure as last run" | Filter logs in code first (context rot). Shadow mode until ~100 labelled rows |
| Sentry / error tracking, on-call runbooks | Error clustering and routing: which service, which owner, user-impacting? | Choice owner; Score severity | Feed only the normalised message + top frames |
| `commitlint`, `semantic-release`, `CHANGELOG` | Commit / PR classification (feat/fix/chore/breaking) and changelog bucketing; commit-message-matches-diff check | Choice type; Noul matches | Jev beat Haiku on commit-type classification in one public head-to-head |
| `.claude/`, `AGENTS.md`, agent hooks, `DANGEROUS_PATTERNS` / `ALLOWED_COMMANDS` | Harness engineering: destructiveness score for shell commands, skill/agent routing, context selection, "did the agent actually finish?" checks | Score reversibility; Choice skill; Noul premature-completion | Deterministic denylist stays authoritative; jev covers the long tail |
| i18n locale files with an AI-translation workflow | Translation QA: meaning preserved, placeholders intact (code checks placeholders; jev checks meaning/register) | Noul per string pair | Batch hundreds of strings per call |
| Test suites with LLM-generated tests or snapshot noise | "Is this test asserting behaviour or implementation detail?"; "is this snapshot diff meaningful?" | Noul | Advisory |
| Docs / README / ADRs | Doc drift: does this section still describe the code it references? | Noul on (doc excerpt, code excerpt) | Weak fit if it needs deep reasoning; keep to local checks |
| Security tooling (CodeQL, dependabot) producing noisy alerts | Alert triage: reachable / relevant / test-only | Choice + confidence -> auto-dismiss only at high confidence | Never the sole gate |
| Support conversations, community forum, feedback widgets | Route to engineering: bug report vs how-to; link to an existing issue | Choice + Noul | Bridges product intake and SDLC |

## Counter-signals: when NOT to propose jev

- **The decision is lexical, not semantic** (exact token match, id lookup, path glob, HTTP status code,
  enum equality). Deterministic code wins on accuracy, cost, and latency. Public evaluations rejected
  grep-line ranking, keyword-frequency tool prediction, and status-code routing for exactly this reason.
- **The decision is arithmetic or temporal** (days since, overdue, totals, thresholds on numbers). Compute in
  code. Jev may *extract* the components; it must not compare or count them.
- **The output is text** (summary, reply, rewrite, generated code, free-form extraction of an unbounded
  value). Not a System One task. Only the *decisions around* the generation (route, verify, gate) fit.
- **The input is not text** (images, audio, binaries) with no text representation available.
- **The rule is a legal, safety, or security invariant** that must hold 100% of the time. Keep it
  deterministic and authoritative; jev can add a *second* semantic check but never replace the invariant.
- **Volume is tiny and a human already looks at every item** with no latency pressure. The saving is
  negligible; say so.
- **A correct deterministic rule already exists** and the only "improvement" would be fuzziness (e.g.
  archive after N days). Do not propose replacing working determinism with judgement.
- **Multi-hop reasoning is required** (property of a property, chained inference). Jev is System One;
  route such cases to a reasoning model instead, and let jev decide *which* cases need it.

## Grep cheatsheet (ripgrep syntax; orient.sh runs these for you)

```
LLM calls:        chat\.completions\.create|messages\.create|generateText|generateObject|generateContent|litellm\.completion
Typed outputs:    response_model=|generateObject|z\.enum\(|response_format|with_structured_output|outlines\.
Keyword rules:    (KEYWORDS|PATTERNS|STOP_?WORDS|BLOCK_?LIST|SPAM_?WORDS)\s*[:=]
String branching: \.includes\(["']|\.contains\(["']|\.startswith\(["']|\.lower\(\)\s*(in|==)
Label regex:      re\.(search|match|findall)\(|new RegExp\(|\.test\(
Fuzzy/dedup:      levenshtein|rapidfuzz|difflib|fuse\.js|is_duplicate|similarity_threshold
Queues:           needs_review|pending_review|reviewed_by|is_flagged|moderation|triage|quarantine
Search:           icontains|ILIKE|to_tsvector|SearchVector|bm25|rerank|order_by\("-created_at"\)
Embeddings:       embeddings\.create|pgvector|cosine_similarity|pinecone|qdrant|VectorField
Free text fields: (TextField|text\(\)|@Column.*text).*(description|body|comment|message|notes)
Intake:           webhook|inbound|intake|inbox|imap|inbound_email
CI/SDLC:          flaky|rerun|retries|CODEOWNERS|labeler|commitlint|PreToolUse|DANGEROUS_PATTERNS
Fragility:        TODO.*(heuristic|hack|fragile|brittle|edge case|false positive)|FIXME|HACK
Function names:   classif|categoriz|score|rank|route|detect|triage|relevan|moderat|prioriti
```
