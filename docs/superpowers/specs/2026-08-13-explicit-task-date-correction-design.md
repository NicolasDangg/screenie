# Explicit Task Date Correction Design

## Problem

For `physics deadline next tue`, Apple Foundation Models reproducibly returns Monday, August 17, 2026 while also emitting “Next Tuesday” as notes. Screenie currently trusts that valid-looking ISO date, persists it, and EventKit correctly mirrors the wrong value.

## Design

Keep Foundation Models as the primary natural-language parser, but treat explicit trailing calendar phrases as deterministic constraints. After guided generation, inspect the final one or two words for a date already supported by `TaskEntryParser`, including `next tue`, a weekday, `today`, `tomorrow`, or an ISO date. Resolve that phrase locally at 09:00 and override only the generated due date. The generated title and notes remain unchanged.

This is preferred over prompt tuning or model retries because explicit dates should not depend on stochastic model output. More flexible phrases such as `tomorrow afternoon` remain model-resolved because they are not exact deterministic suffixes.

## Verification and Existing Data

Add a regression test in which the model output says Monday but the source entry says `next tue`; the reconciled result must be Tuesday, August 18. Preserve generated dates when the input has no supported explicit suffix. Run the full suite, reinstall the signed app, back up `tasks.json`, correct the uniquely identified `Physics Deadline` task by one day, and relaunch so its existing EventKit event is updated through the stored event identifier.
