# Garmin Smart Alarm Validation Plan

## Goal
Build a repeatable local validation harness for the Garmin smart alarm app using real sleep data, then iteratively fix the app logic until it triggers as expected on replayed data and remains compatible with Garmin Venu 2 constraints.

## Assumptions
- We can modify the app’s detection logic and architecture if current heuristics perform poorly.
- Stronger success bar means multiple replayable pass/fail scenarios, not a single happy-path demo.
- Public sleep datasets plus synthetic/replayed scenarios are both acceptable.
- We should first build an offline evaluator, then constrain/replay against the Garmin background model (60 s wakes, limited signals, noisy/missing samples).
- Venu 2-available signals should be used when practical, including motion if CIQ support and test data make it worthwhile.

## Success Tests
1. A local test harness exists and can replay one or more real sleep datasets.
2. The harness can score whether the alarm would fire, when, and why.
3. The replay can emulate Garmin constraints (e.g. 60-second background wake cadence, limited observable signals).
4. The app logic is updated based on findings, not just documented.
5. We have evidence from multiple scenarios that the alarm fires inside the intended wake window or at fallback target time when no better trigger exists.
6. The project includes a documented workflow so the tests can be rerun locally.

## Work Stages
1. Inspect current code and formalize current algorithm.
2. Identify usable public sleep datasets with labels/signals relevant to Venu 2.
3. Build an offline replay/evaluation harness.
4. Create Garmin-constrained replay mode.
5. Compare current algorithm against datasets.
6. Improve logic and iterate until results are acceptable.
7. Align app implementation with validated logic.
8. Document workflow and results.
9. Run final verification and checkpoint in git.

## Deliverables
- Test harness files in-project
- Notes on chosen datasets and rationale
- Updated app logic if needed
- Test results / verification notes
- Git commit(s)
