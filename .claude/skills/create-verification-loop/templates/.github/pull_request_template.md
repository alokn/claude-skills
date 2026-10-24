<!--
Write this body to a file and open the PR with `scripts/pr.sh --title "…" --body-file <file>`
(or `gh pr create --body-file <file>`). scripts/pr-body.py checks it first, in the hook and in
CI: every section present and filled, "None" where it applies; an untouched comment is empty.
scripts/pr.sh appends a "Verification" block with the summary lines of your green full gate and
the SHA they passed on, so don't paste that output here or add a heading named "Verification".
-->

## Issue

<!-- #N (Closes #N when this PR fully resolves it), or "None: <why>". -->

## Why

<!-- One or two lines: what was wrong or missing, and for whom. -->

## What changed

<!-- Behaviour, as bullets. End with the two lines below, each "None" or what it is. -->

- 

Security and isolation: <!-- None, or what it touches (auth, tenancy, secrets, input from outside) and how that was proven. -->
Deploy notes: <!-- None, or config, env, migration order or rollout steps. -->

## Decisions and trade-offs

<!-- One line per decision: what was decided, the alternatives, why, and the cost if it is wrong.
Declined review findings go here too, with the reason. "None: mechanical" only for a mechanical change. -->

## Checks run beyond the gate

<!-- Only what you ran, each with its command and the result you read. Then what the change
deserves that you didn't run, and why. -->

## Affected boundaries

<!-- "None", or each one crossed, by path: a migration, a locked test (setup-only or assertion,
and who approved an assertion change), a shared contract, a dependency or the toolchain. -->

## Review

<!-- The reviewer, the rounds and the findings fixed. Declined findings go under Decisions and trade-offs. -->

## Follow-ups and flakes

<!-- "None", or the issues filed (#N) and the flakes recorded. -->

## Ratchet drops

<!-- Only when verify-baseline.json's allowedDrops changes (scripts/verify.sh full --allow-drop);
otherwise delete this section. For a test count, one row per removed test. -->

| Figure or removed test | Reason | What still covers it |
|---|---|---|
