---
id: uc-media-content-sponsor-segment-detection
title: Detect sponsor segments in a video by classifying caption windows
verdict: conditional
domain: media-content
decision_shapes: [classification, detection]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/valentynkit/jev-skip  (23 videos: "77%" of crowd-marked sponsor seconds, "34 seconds/hour" false positives, "$0.0008 per video", "0.9 s"; "non-English captions perform weaker")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 3 date and time comparison; mode 5 large state)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input)
related: [uc-media-content-ai-writing-slop-detection, uc-data-ml-map-reduce-corpus-labelling, au-non-english-at-scale-unevaluated, au-date-ordering-and-overdue]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to find the sponsor reads in a video?" Also: "can we auto-skip
sponsorships without waiting for SponsorBlock submissions?", "can jev replace a crowd-sourced
segment database?", "how do we handle a video nobody has marked yet?".

## Verdict

**Conditional.** The measured result is genuinely useful and genuinely lossy: over 23 videos the
public implementation catches "77%" of the sponsor seconds the SponsorBlock crowd marked, at
"34 seconds/hour" of false positives, "$0.0008 per video" and "0.9 s". That is a good cold-start
answer for the long tail of videos with no crowd submissions, and a bad replacement for a crowd
database that already covers a video. The conditions: the user can turn it off, the crowd
database wins where it has data, and the non-English caveat is respected — the author states
plainly that "non-English captions perform weaker".

## What jev decides

Code fetches the caption track and cuts it into overlapping windows of roughly 20-30 seconds,
each carrying its own text plus the window before and after for context. One call per window,
parallelised. The timestamps never enter a question.

```
is_sponsor_read: Noul
  instructions: {question: "Is the speaker in `window_text` delivering a paid promotion?",
                 focus: "Judge this window's speech, not the video's overall topic."}
  true:  "The speaker is promoting a product or service in exchange for sponsorship - a
          discount code, a tracked URL, 'thanks to X for sponsoring', a read-out feature list
          for an unrelated product."
  false: "The speaker mentions a product as part of the video's actual subject, recommends
          something unpaid, plugs their own merchandise or channel membership, or asks for a
          like and subscribe."

is_self_promotion: Noul
  instructions: "Is the speaker promoting their own channel, course, Patreon or merchandise?"
```

The `false` criterion carries the entry. A review channel talks about products for the whole
video; the distinction is the paid relationship, not the subject. `is_self_promotion` is
separated out because users want different behaviour for it, and because collapsing it into
`is_sponsor_read` is what produces the false skips.

No confidence band for display, one for action: skip only above a floor fitted on your own
labelled videos, and show the user the segment boundary so they can un-skip.

## What stays in code

Caption fetch, windowing, the merge of adjacent positive windows into one segment, and — this
is the important one — **boundary timestamps come from the caption cue times, never from jev**.
Asking a System One model where a segment starts is failure mode 3 (dates and times read as
text, not ordered quantities). Also in code: the SponsorBlock lookup that runs first, the cache
keyed on video id, the per-user on/off switch, and the minimum-segment-length rule.

## Numbers

From https://github.com/valentynkit/jev-skip, 23 videos: catches "77%" of the sponsor seconds
SponsorBlock's crowd marked; "34 seconds/hour" of false positives; "$0.0008 per video"; "0.9 s".
Explicitly: "non-English captions perform weaker" — no figure is given for how much weaker, so
treat any non-English language as unmeasured.

Read those numbers honestly. 77% recall against crowd marks means roughly a quarter of sponsor
time still plays. 34 seconds per hour of false positives means about 0.9% of the video is
wrongly skipped — small in aggregate, and extremely annoying if it lands on the punchline. n=23
is a first look by one author with no reruns reported.

Cost method: `input_tokens ~= chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A
one-hour video at ~150 words per minute is roughly 54,000 characters; cut into 25-second windows
with context, plus ~900 characters of criteria per call, that is on the order of 20,000 tokens
total, **~$0.0008** — which is exactly the published per-video figure.

Closest failure mode: **3, date and time comparison**, avoided entirely by keeping timestamps in
code. Runner-up **5**: never send the whole transcript in one state.

## When the verdict flips

- **The crowd database already covers your videos.** SponsorBlock is free, exact to the second
  and human-verified. Use it first; jev is the fallback for unmarked videos.
- **Non-English captions without your own check.** The author's own caveat. Measure per language
  before enabling.
- **No captions, or auto-captions that mangle brand names.** Jev takes text only; garbage in.
- **The skip is irreversible or invisible.** If the user cannot see or undo a skip, 34
  seconds/hour of false positives becomes a trust problem rather than an annoyance.
- **You want to insert, remove or rewrite content.** Jev classifies; it does not generate.

## Alternatives considered

- **SponsorBlock (crowd-sourced).** The incumbent and better wherever it has data: exact
  boundaries, human-verified, free. Blind to every video nobody submitted.
- **Keyword rules over captions** ("use code", "sponsored by", a discount URL). Free and catches
  the obvious reads; misses the soft native integration and fires on a creator saying the word
  "sponsor". A reasonable pre-filter to cut the number of jev calls.
- **Audio fingerprinting of ad stings.** Precise for programmatic insertions; useless for a host
  read.
- **Frontier LLM over the transcript.** Better at the ambiguous native integration, and seconds
  plus cents per video — roughly three orders of magnitude more per video than the measured
  $0.0008.
- **Trained classifier on SponsorBlock labels.** The strongest long-run option: millions of
  crowd-labelled segments already exist as training data. Jev buys the cold start, not the
  ceiling.

## Sources

- https://github.com/valentynkit/jev-skip — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
