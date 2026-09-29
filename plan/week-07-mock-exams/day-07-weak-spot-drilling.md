# Week 7 · Day 7 (Nov 11) — Weak-spot drilling
**Domain:** All CKS domains (targeted remediation) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Re-do every flagged task from Nov 5-10 cold and clean under time pressure.
- Convert each recurring gap into a one-line checklist item or cheatsheet addition.
- Exit Week 7 with an empty "not clean" list before moving to Week 8.

## Theory
**Deliberate practice loop.** For each weak item: (1) read only the one-line gap from your log, (2) attempt cold with a timer, (3) compare against the answer file, (4) if it fails, study that theory section, wait, and redo a fresh variant (change names, ports, namespaces), (5) log the time. "Clean" means: correct on first submission, within the time target (~15 min for a normal task, ~8 min for a small one), with no doc lookups beyond exact field names.

**Common gap classes and remedies.**
- Concept gap: re-read the theory of the mapped day, restate it aloud, rebuild.
- Recall gap (flag/field): add it to `cheatsheet.md` and write it from memory twice.
- Speed gap: script a scaffold with `$do`, learn the docs page location, use `kubectl explain --recursive`.
- Carelessness (context/namespace/path): add a pre-flight checklist line: context, namespace, output path, verify command.

**Patterns to prioritise.** Static pod manifest edits, API server flags plus volume mounts (audit, encryption), NetworkPolicy selectors and DNS egress, PSA-compliant securityContext, Falco rule loading, `jq` on audit logs, Kyverno patterns, cosign flag set, upgrade order.

## Prerequisites
- Miss log from `plan/week-07-mock-exams/day-06-killersh-simulator.md` (all rows from Days 1-6).
- Answer files for Days 1-5 for post-attempt comparison only.
- Fresh namespaces (delete leftovers from earlier days).

## Task
1. Consolidate the miss log: merge rows from Days 1-6, de-duplicate, and rank by (a) points lost, (b) repeated topics. Keep the top 8-10 items.
2. For each item in ranked order, run the loop from Theory: cold attempt with a timer (write the start/stop time), compare, note whether it was clean.
3. For any item that is not clean, do a remediation pass: study the mapped theory, then repeat it with different names/ports until it is clean, recording each attempt.
4. Rewrite each recurring gap as a one-line checklist entry; append the most valuable 5-10 to `cheatsheet.md` sections you own (do not edit the repo's other files unless you want to; a personal note is enough).
5. Do a final 30-minute mini-set: pick three of your previously weakest tasks, run them back-to-back with no lookups, and check that all three are clean.
6. Fill in the tracking template and the exit gate below.

**Drill tracker**

| # | Item (task / topic) | Source (day / killer.sh Q#) | Gap | Attempt 1 (time, clean?) | Attempt 2 | Attempt 3 | Checklist line written |
|---|---|---|---|---|---|---|---|
| 1 |   |   |   |   |   |   |   |
| 2 |   |   |   |   |   |   |   |
| 3 |   |   |   |   |   |   |   |
| 4 |   |   |   |   |   |   |   |
| 5 |   |   |   |   |   |   |   |
| 6 |   |   |   |   |   |   |   |
| 7 |   |   |   |   |   |   |   |
| 8 |   |   |   |   |   |   |   |

**Exit gate (all must be checked before Week 8)**
- [ ] Every row in the drill tracker has a clean attempt within the time target.
- [ ] Mini-set of three weakest tasks done in 30 minutes, all clean.
- [ ] Top 5 recurring gaps are in the cheatsheet or checklist.
- [ ] killer.sh session #2 still unused and scheduled for Week 8.

## Check your work
- Each drilled item ends with the same verification you would use on the exam (a `get`, `curl`, `jq`, or `can-i` result), not just "applied".
- The tracker shows at least one clean run per item, timed.
- Nothing is marked clean if you looked up the solution during the attempt.

## Answer
[answers/week-07-mock-exams/day-07-weak-spot-drilling.md](../../answers/week-07-mock-exams/day-07-weak-spot-drilling.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete lab namespaces created during drilling and remove leftover files in `/tmp` and temporary manifests from `/etc/kubernetes/manifests` (backups must never live there).
