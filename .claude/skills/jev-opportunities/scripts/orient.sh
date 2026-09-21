#!/usr/bin/env bash
# orient.sh — deterministic repo survey for the jev-opportunities skill.
# Usage: orient.sh [repo-path] [--lens A|B|C]   (--lens prints a ready-to-paste excerpt for one scanner)
# Prints a Markdown survey: stack, size, modules, git activity, existing AI usage,
# and grep-based hotspots grouped by jev opportunity signal. Read-only.
set -uo pipefail

ROOT="${1:-.}"
LENS=""
[ "${2:-}" = "--lens" ] && LENS="$(echo "${3:-}" | tr a-z A-Z)"
if [ -n "$LENS" ]; then
  # Emit only the sections a single scanner lens needs: header, Stack, Size, Existing AI, its own signal section, Domain hints.
  case "$LENS" in A) KEEP="A)";; B) KEEP="B)";; C) KEEP="C)";; *) echo "orient.sh: --lens must be A, B or C" >&2; exit 2;; esac
  bash "$0" "$ROOT" | awk -v keep="$KEEP" '
    /^## / { sec=$0; show = (sec ~ /Stack|Size|Existing AI|Domain hints/) || index(sec, "Signals: " keep) == 1 || index(sec, "Signals: " keep) > 0 }
    NR==1 || /^Path: / { print; next }
    show { print }'
  exit 0
fi
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "orient.sh: cannot cd to $1" >&2; exit 2; }
cd "$ROOT"

# ---------- helpers ----------
EXCLUDES=(node_modules .git dist build out .next .turbo vendor venv .venv __pycache__ coverage target .cache
          migrations locales locale i18n fixtures snapshots __snapshots__ .terraform .yarn .pnpm-store tests test __tests__ e2e)
have() { command -v "$1" >/dev/null 2>&1; }

if have rg; then
  RG_EX=(); for e in "${EXCLUDES[@]}"; do RG_EX+=(--glob "!**/$e/**"); done
  RG_EX+=(--glob '!*.lock' --glob '!*-lock.json' --glob '!*lock.yaml' --glob '!*.min.js' --glob '!*.min.css' --glob '!*.map' --glob '!*.svg' --glob '!*.snap' --glob '!*.stories.*' --glob '!LICENSE*' --glob '!workbox-*.js' --glob '!sw.js')
  # search: pattern [extra rg args...] -> "count<TAB>file" sorted desc
  hits() { rg -c --no-messages -i "${RG_EX[@]}" "$@" . 2>/dev/null | sort -t: -k2 -nr | awk -F: '{print $NF"\t"$1}' | sed 's/^\([0-9]*\)\t\.\//\1\t/' ; }
  total() { rg -c --no-messages -i "${RG_EX[@]}" "$@" . 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}'; }
  first() { rg -n --no-messages -i -m 1 "${RG_EX[@]}" "$@" . 2>/dev/null | head -"${FIRST_N:-3}" | sed 's/^\.\///'; }
else
  GREP_EX=(); for e in "${EXCLUDES[@]}"; do GREP_EX+=(--exclude-dir="$e"); done
  GREP_EX+=(--exclude='*.lock' --exclude='*-lock.json' --exclude='*lock.yaml' --exclude='*.min.js' --exclude='*.min.css' --exclude='*.map' --exclude='*.svg' --exclude='*.snap' --exclude='*.stories.*' --exclude='LICENSE*' --exclude='workbox-*.js' --exclude='sw.js')
  hits()  { grep -rIc -i -E "${GREP_EX[@]}" "$1" . 2>/dev/null | grep -v ':0$' | sort -t: -k2 -nr | awk -F: '{print $2"\t"$1}' | sed 's/^\([0-9]*\)\t\.\//\1\t/'; }
  total() { grep -rIo -i -E "${GREP_EX[@]}" "$1" . 2>/dev/null | wc -l | tr -d ' '; }
  first() { grep -rIn -i -E -m 1 "${GREP_EX[@]}" "$1" . 2>/dev/null | head -"${FIRST_N:-3}" | sed 's/^\.\///'; }
fi

section() { printf '\n## %s\n\n' "$1"; }
signal() {
  # signal "Label" "regex" [max_files]
  local label="$1" pat="$2" n="${3:-8}"
  local t; t="$(total "$pat")"
  printf -- '- **%s** — %s hits' "$label" "$t"
  if [ "$t" != "0" ]; then
    printf '\n'
    hits "$pat" | head -"$n" | awk -F'\t' '{printf "    - %s (%s)\n", $2, $1}'
  else
    printf '\n'
  fi
}

# ---------- header ----------
echo "# Repo orientation: $(basename "$ROOT")"
echo
echo "Path: \`$ROOT\`  ·  Generated: $(date -u +%Y-%m-%dT%H:%MZ)  ·  Tool: $(have rg && echo ripgrep || echo grep)"

# ---------- stack ----------
section "Stack (manifests found)"
for f in package.json pnpm-workspace.yaml turbo.json nx.json lerna.json pyproject.toml requirements.txt Pipfile setup.py \
         go.mod Cargo.toml Gemfile composer.json pom.xml build.gradle build.gradle.kts mix.exs Package.swift *.csproj *.sln \
         Dockerfile docker-compose.yml docker-compose.yaml serverless.yml vercel.json netlify.toml fly.toml render.yaml \
         CLAUDE.md AGENTS.md .cursorrules; do
  for m in $f; do [ -e "$m" ] && echo "- \`$m\`"; done
done 2>/dev/null
[ -d .github/workflows ] && echo "- \`.github/workflows/\` ($(ls .github/workflows | wc -l | tr -d ' ') workflows)"
[ -d .claude ] && echo "- \`.claude/\` ($(find .claude -name '*.md' | wc -l | tr -d ' ') md files: skills/commands/agents)"
[ -d .husky ] && echo "- \`.husky/\` git hooks"
[ -f .pre-commit-config.yaml ] && echo "- \`.pre-commit-config.yaml\`"

# ---------- size ----------
section "Size"
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  FILES=$(git ls-files | wc -l | tr -d ' ')
  echo "- Tracked files: $FILES"
  echo "- By extension (top 12):"
  git ls-files | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' | sort | uniq -c | sort -rn | head -12 | awk '{printf "    - .%s: %s\n", $2, $1}'
  echo "- Top-level directories:"
  git ls-files | awk -F/ 'NF>1{print $1}' | sort | uniq -c | sort -rn | head -12 | awk '{printf "    - %s/ (%s files)\n", $2, $1}'
  echo "- Second-level directories (top 15):"
  git ls-files | awk -F/ 'NF>2{print $1"/"$2}' | sort | uniq -c | sort -rn | head -15 | awk '{printf "    - %s/ (%s files)\n", $2, $1}'
else
  echo "- Not a git repo; file count: $(find . -type f | wc -l | tr -d ' ')"
fi

# ---------- git activity ----------
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  section "Git activity (last 90 days)"
  SHALLOW=$([ -f .git/shallow ] && echo " (shallow clone: history truncated)"); echo "- Commits: $(git log --since='90 days ago' --oneline 2>/dev/null | wc -l | tr -d ' ')$SHALLOW"
  if [ -z "$SHALLOW" ]; then
    echo "- Most-changed directories:"
    git log --since='90 days ago' --name-only --pretty=format: 2>/dev/null | grep -v '^$' | awk -F/ 'NF>1{print $1"/"$2}' | sort | uniq -c | sort -rn | head -8 | awk '{printf "    - %s (%s changes)\n", $2, $1}'
  else
    echo "- Churn not available on a shallow clone"
  fi
fi

# ---------- existing AI ----------
section "Existing AI / ML usage"
signal "TypeSafe / jev already present" 'typesafe[-_]sdk|@typesafe-ai|api\.typesafe\.ai|systemone|system_one|jev-latest' 10
signal "LLM SDKs and gateways" '\b(openai|anthropic|@anthropic-ai|google-generativeai|@google/generative-ai|genai|litellm|langchain|llamaindex|llama_index|vercel/ai|"ai/react"|from "ai"|openrouter|bedrock-runtime|mistralai|cohere|ollama|groq)\b' 12
signal "LLM chat/completion call sites" 'chat\.completions\.create|messages\.create|generateText|generateObject|streamText|responses\.create|generateContent|invoke\(.*prompt|\.complete\(|litellm\.completion' 12
signal "Typed-output LLM libs (schema already defined: strong swap signal)" 'instructor\.|response_model=|generateObject|z\.enum\(|response_format|json_schema|outlines\.|baml_client|structured_output|with_structured_output' 12
signal "Embeddings / vector search" '\b(embedding|embeddings\.create|pgvector|cosine_similarity|pinecone|weaviate|qdrant|chromadb|faiss|vector_store|VectorField)\b' 10
signal "Classical NLP libs" '\b(vader|textblob|nltk|spacy|sentiment|langdetect|fasttext|sklearn\.naive_bayes|akismet|perspectiveapi|profanity|bad-words|leo-profanity)\b' 8
signal "LLM-as-judge / eval harness" '\b(judge|grader|evaluate_response|llm_eval|rubric|score_response|eval_set|golden)\b' 8

# ---------- category A: replace ----------
section "Signals: A) replace existing logic (heuristics, rules, queues)"
signal "Keyword / pattern lists used as rules" '(KEYWORDS|PATTERNS|STOP_?WORDS|BLOCK_?LIST|BLACK_?LIST|ALLOW_?LIST|DENY_?LIST|BANNED_?WORDS|TRIGGER_?WORDS|SPAM_?WORDS)\s*[:=]' 10
signal "String-content branching (includes / contains / startswith chains)" '\.includes\(["'"'"']|\.contains\(["'"'"']|\bin\s+(text|message|body|title|subject|content|query)\b|\.startswith\(["'"'"']|\.lower\(\)\s*(in|==)|toLowerCase\(\)\s*(===|\.includes)' 12
signal "Regex used to label or classify text (not just validate)" 're\.(search|match|findall|compile)\(|new RegExp\(|\.test\(|\.match\(/|preg_match|Regex\.' 12
signal "Sentiment / urgency / intent / spam / priority heuristics" '\b(sentiment|urgency_score|is_urgent|detect_intent|intent_(type|score)|is_spam|spam_score|toxicity|priority_score|severity_score|classify_|categori[sz]e_|detect_language|guess_(type|category|intent))\b' 12
signal "Fuzzy matching / dedup" '\b(levenshtein|fuzzywuzzy|rapidfuzz|difflib|jaro|soundex|metaphone|fuse\.js|string-similarity|similarity_threshold|is_duplicate|find_duplicates|dedup)\b' 10
signal "Manual review / moderation / approval queues" '\b(review_queue|moderation|moderat(e|or)|needs_review|pending_review|flagged|is_flagged|approved_by|reviewed_by|reviewed_at|triage|quarantine|escalat)\b' 12
signal "Search & ranking (rerank candidates)" '\b(icontains|ILIKE|to_tsvector|SearchVector|SearchRank|TrigramSimilarity|full_text|fulltext|bm25|elasticsearch|opensearch|meilisearch|typesense|algolia|rerank|relevance|ORDER BY created_at|order_by\("-created_at"\))\b' 12
signal "Rule engines / automation rules with conditions" '\b(rules?\.ya?ml|rule_engine|json-rules-engine|automation_rule|conditions?\s*[:=]\s*\[|when\s*:\s*\{|trigger_conditions)\b' 8
signal "Free-text parsing for structured values (dates, amounts, ids)" '\b(dateparser|dateutil\.parser|chrono|date-fns/parse|parse_amount|parse_price|extract_(date|amount|email|phone|number)|money\.parse)\b' 8

# ---------- category B: new features ----------
section "Signals: B) unstructured text flowing through the product (feature surface)"
signal "Free-text model fields" '(TextField|JSONField|LongText|text\(\)|String\(|varchar|@Column\(.*text|type:\s*["'"'"']text|z\.string\(\)\.min|richText|markdown)\b.*\b(description|comment|body|content|message|notes?|title|summary|feedback|review|bio|reason)\b' 15
signal "Inbound message / webhook / email intake" '\b(webhook|inbound|incoming|intake|inbox|imap|mailgun|sendgrid.*inbound|postmark|twilio|slack_event|events\.on|on_message)\b' 10
signal "Notifications / digests / alerts (noise gating)" '\b(should_notify|notification_(filter|rule|preference|setting)s?|digest|batch_notifications|mute|snooze|nudge|alert_(rule|threshold)|noise)\b' 10
signal "Tags / labels / categories / priority fields (auto-suggest surface)" '\b(priority|severity|category|label|tag|assignee)s?\s*=\s*(models\.|Column\(|z\.|t\.|DataTypes|Sequelize|Schema\.)|(PRIORITY|SEVERITY|CATEGORY)_CHOICES|auto_?tag|suggest(ed)?_(label|tag|assignee|priority)' 12
signal "Debounced text input hitting the backend (real-time judgement surface)" '(debounce|useDebounce|throttle)\w*\(.*(fetch|axios|service|api|search|suggest)|onChange.*(fetch|api\.|service\.)' 8
signal "Import / migration / mapping of external records" '\b(importer|import_(issues|data|records|csv|items)|csv_import|parse_csv|read_csv|xlsx|field_mapping|map_fields|column_mapping|normalize_(name|title|record|entity)|canonicali[sz]e)\b' 10
signal "Existing AI feature surfaces to guardrail/verify" '\b(ai_?assistant|ai_?service|copilot|rephrase|summari[sz]e|llm_|gpt_|prompt_template|system_prompt)\b|/ai/' 10

# ---------- category C: SDLC ----------
section "Signals: C) SDLC / CI / dev workflow"
if [ -d .github/workflows ]; then
  echo "- Workflows:"; ls .github/workflows | sed 's/^/    - /'
fi
[ -d .github/ISSUE_TEMPLATE ] && echo "- Issue templates: $(ls .github/ISSUE_TEMPLATE | tr '\n' ' ')"
[ -f .github/PULL_REQUEST_TEMPLATE.md ] || [ -d .github/PULL_REQUEST_TEMPLATE ] && echo "- PR template present"
[ -f .github/CODEOWNERS ] || [ -f CODEOWNERS ] && echo "- CODEOWNERS present (review routing proxy)"
[ -f .github/labeler.yml ] && echo "- labeler.yml present (path-based labels)"
[ -f .github/dependabot.yml ] && echo "- dependabot.yml present"
[ -f commitlint.config.js ] || [ -f .commitlintrc* ] 2>/dev/null && echo "- commitlint present"
[ -f .releaserc* ] 2>/dev/null || [ -f release.config.js ] && echo "- semantic-release present"
signal "Retry / flaky-test handling" '\b(retries?\s*[:=]|flaky|rerun|re-run|retry-failed|jest\.retryTimes|pytest-rerunfailures|@flaky|known_flaky|quarantine)\b' 8
signal "Log / error triage code" '\b(parse_log|log_parser|classify_error|error_type|exception_type|known_errors|error_patterns|stack_?trace_(parse|match)|sentry\.(capture|init)|rollbar|bugsnag)\b' 8
signal "Agent / hook allow-deny lists (harness engineering)" '\b(DANGEROUS_PATTERNS|ALLOWED_COMMANDS|BLOCKED_COMMANDS|DENY_PATTERNS|PreToolUse|PostToolUse|allowed-tools|disallowed-tools)\b' 8
signal "Release notes / changelog / PR description generation" '\b(CHANGELOG|release[-_]?notes|conventional[- ]commits|pr-description|semantic-release|commitizen|commitlint)\b' 8
signal "Localisation pipeline (translation QA surface)" '\b(i18n|l10n|translation_(check|review|sync)|sync:check|translate)\b' 6
signal "Fragility markers in comments" 'TODO.*(heuristic|hack|fragile|brittle|improve|better way|edge case|false positive|false negative)|FIXME|HACK|XXX' 10

# ---------- domain ----------
section "Domain hints (read these first)"
for f in README.md README.rst docs/README.md CLAUDE.md AGENTS.md CONTRIBUTING.md ARCHITECTURE.md docs/architecture.md; do
  [ -f "$f" ] && echo "- \`$f\` ($(wc -l < "$f" | tr -d ' ') lines)"
done
echo
echo "_Hotspot files above are candidates only. Every finding must be confirmed by reading the code and citing file:line with a verbatim snippet._"
