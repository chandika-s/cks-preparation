# Week 7 · Day 6 (Nov 10) — killer.sh simulator attempt #1
**Domain:** All CKS domains (full-exam simulation) | **Est. time:** 120 min exam + 90 min review | **Cluster:** killer.sh environment (not kind-cks)

## Objectives
- Sit one full 2-hour simulator session under real exam conditions.
- Score yourself and log every miss with a root cause.
- Map every missed question back to the week/day in this plan so Day 7 drilling is targeted.

## Theory
**Simulator facts.** Your exam purchase includes two killer.sh sessions. Each session gives roughly 36 hours of access from the moment you activate it; the task set and environment are identical across both sessions. The simulator is deliberately harder than the real exam, with more tasks and time pressure; scoring 60-70% on the first attempt is normal. Start the 36-hour clock only when you can commit the two uninterrupted hours; you can reread solutions and remain in the environment for the rest of the window. The environment is a remote terminal with multiple clusters/contexts and a browser-based question list: every question begins with a context or SSH instruction.

**Exam-day habits to rehearse.** Read the whole question and note the required context/namespace before typing. Set aliases and `export do="--dry-run=client -o yaml"` at start. Flag hard questions and move on after ~8 min stuck; return with leftover time. Use the docs allow-list (kubernetes.io, tool docs) via the exam browser only. Write files and outputs exactly at the paths given. Verify each change (`get`, `describe`, `curl`) before moving on. Take care with static pod edits: a syntax error can take down the API server; keep a backup outside the manifests directory.

**Time budget.** ~5 min setup, 100 min questions, 15 min review/flagged questions. Prioritise by weight; do easy high-value tasks first.

## Prerequisites
- Weeks 1-6 and Days 1-5 of this week completed; cheatsheet.md reviewed.
- Two uninterrupted hours and a second hour afterwards for review. Quiet room, no external notes other than what the real exam permits (kubernetes.io, tool docs).
- Note the activation time here: __________ (36 h window ends: __________).

## Task
1. Activate killer.sh session #1 (Nov 10). Record the start time and the end of the 36-hour window above.
2. Set up the shell: aliases, `export do`, `export now`, vim settings (`set expandtab tabstop=2 shiftwidth=2`), and `kubectl` completion.
3. Work through the question list for a strict 2 hours. No pausing. For every question, write a one-line status in the table below immediately after leaving it (Done / Partial / Skipped, minutes spent).
4. When time expires, stop. Do not fix anything after the clock.
5. Open the scoring/solutions. For each question compare your solution to the official one. Mark it `OK`, `Partial` or `Miss`, note the gap in one line, and map it to the week/day in the plan using the mapping table in the answer file.
6. For every Partial/Miss, add a row to the miss log (copy this table into `workspace/week7-miss-log.md` or a note of your choice) and carry it into Day 7.
7. Compute score: (points earned / total) = ______ %. Note the three slowest questions and the three least-confident topics.
8. Do not start session #2 yet; keep it for the Week 8 final check.

**In-session tracker**

| Q# | Domain / topic | Weight (if shown) | Status (Done/Partial/Skipped) | Minutes | Notes |
|----|----------------|-------------------|-------------------------------|---------|-------|
|    |                |                   |                               |         |       |

**Miss log**

| Source (mixed set day / killer.sh Q#) | Task | Gap (flag, selector, path, concept) | Root cause (didn't know / forgot / slow / typo) | Plan reference (week/day) | Drilled clean on Day 7? (date, time taken) |
|---|---|---|---|---|---|
|   |   |   |   |   |   |

## Check your work
- All questions have a status row and every non-OK item has a miss-log row with a plan reference.
- The 36-hour window and the score are recorded.
- No item in the log says only "wrong"; each names a concrete gap.
- You can state your three weakest domains in one sentence.

## Answer
[answers/week-07-mock-exams/day-06-killersh-simulator.md](../../answers/week-07-mock-exams/day-06-killersh-simulator.md) — Attempt the task first; only then open the answer.
