# Week 8 · Day 1 (Nov 12) — killer.sh simulator attempt #2 — Answers
Back to task: [day-01-killersh-attempt-2](../../plan/week-08-final-review/day-01-killersh-attempt-2.md)

## Solution
Model process (not a lab).

**Before the clock**
1. Fresh tab set: killer.sh terminal, one docs tab with kubernetes.io/docs. Phone away.
2. In the terminal:
```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```
3. Start the timer at question 1.

**Time-boxing during the run (120 min, 17 questions)**
- Average budget about 7 min per question; hard cap 10–12 min.
- Pass 1 (about 85 min): all questions in order of ease, skipping anything that stalls at 10 min. Write "Q#, skipped, why" in the scratch list.
- Pass 2 (about 25 min): flagged questions, highest weight first.
- Final 10 min: verify risky edits (static pod manifests, audit policy, admission config), no half-finished YAML.
- Never sit at a blank screen: attempt the first easy sub-step for partial credit.

**Per-question loop**
1. `k config use-context <ctx>` (killer.sh prints the exact command).
2. Read the entire question, underline nouns: namespace, names, paths, values.
3. Do it, using generators and `$do`.
4. Verify with a command whose output proves the requirement.
5. Record result and move on.

**killer.sh review method (immediately after)**
1. Read the solution for every question, including ones you got right (faster alternatives).
2. Score each: full / partial / zero.
3. Classify every miss: (a) knowledge gap, (b) speed, (c) misread requirement, (d) wrong context/namespace, (e) did not verify.
4. Fix action per class: (a) read the linked week note and redo the lab; (b) drill the command 3 times timed and add to `cheatsheet.md`; (c) rewrite the requirement in your own words, list constraints; (d) add context check to the loop; (e) write the verification command next to the task.
5. Redo each miss in the live simulator until it passes unaided, timed.
6. Compare with attempt #1 by domain; the lowest domain (weighted) gets Day 2 time first.
7. Extract at most 8 Day 2 targets.

Example review log:

| Q | Score | Category | Root cause | Fix |
|---|---|---|---|---|
| 5 | 0 | a | Did not know audit policy `omitStages` | Redo week-06 audit lab |
| 9 | partial | b | Looked up seccomp path in docs, 6 min | Drill `/var/lib/kubelet/seccomp/` path |
| 12 | 0 | d | Applied in default context | Add `use-context` habit |

## Expected output
- A completed 2 h run, a per-question score sheet, a review log like above, and a Day 2 list of at most 8 items.
- Typical outcome: killer.sh score lower than real exam difficulty would give; a score above roughly 67% with time to spare is a good sign.

## Why it works
- Simulating exam conditions trains time-boxing and context discipline, the two most common causes of lost points.
- Classifying misses turns a raw score into a targeted plan; redoing until unaided converts recognition into recall.

## Common mistakes / exam gotchas
- Pausing or looking at solutions mid-run.
- Spending 25 min on one 4% question.
- Reviewing only the misses and ignoring slow correct answers.
- Redoing tasks by reading the solution and copying instead of from memory.
- Starting new topics after the run instead of fixing the list.

## Cleanup
- None on `kind-cks`. The simulator environment expires on its own after 36 h.
