<!--
Open the PR with `scripts/pr.sh --title "…" --body-file <this template, filled in>`. It appends
a "Verification" block with the summary lines of your green full gate and the SHA they passed
on, so don't paste that output here, and don't add a heading of your own named "Verification".
-->

Closes #N <!-- the issue this PR fully resolves; Refs #N for one it only advances -->

## Problem and resulting behaviour

<!-- What was wrong or missing, and for whom. Then what happens now. -->

## Affected boundaries

<!-- Which of these the change crosses, or "none": a shared contract; the database (a
migration, a column); the gate (a test, a figure, verify-baseline.json, CI); a dependency or the
toolchain. -->

## Checks run beyond the gate

<!-- Only what you ran, each with its command and the result you read. -->

## Proposed, not run

<!-- Validation the change deserves that you didn't run, and why. "None" is a fine answer. -->

## Remaining limitations

<!-- What this doesn't do, and the follow-up issue for each (#N). -->
