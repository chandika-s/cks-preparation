# Week 8 · Day 1 (Nov 12) — killer.sh simulator attempt #2
**Domain:** All domains (full exam simulation) | **Est. time:** 2 h run + 60–90 min review | **Cluster:** killer.sh simulator (not kind-cks)

## Objectives
- Complete the second and final killer.sh CKS session under real exam conditions (2 hours, no pauses).
- Review every miss immediately afterward and classify its cause.
- Leave with a short list of weak spots for Day 2.

## Theory
- The CKS exam is performance-based, 2 hours, Kubernetes v1.35, multiple clusters/contexts, remote proctored. See `00-exam-and-cka-renewal.md`.
- Registration includes two killer.sh sessions (36 h access each, 17 questions per session). This is attempt #2; the environment stays live for 36 h, so review can use it, but the timed run must not be interrupted.
- killer.sh is deliberately harder than the real exam; the score matters less than the miss analysis. Pass mark on the real exam is 67%.
- Weighted scoring: partial credit exists per task; a partly correct answer beats a blank one.
- Miss categories: (a) knowledge gap, (b) speed/lookup time, (c) misread requirement, (d) wrong context/namespace, (e) did not verify.

## Prerequisites
- Attempt #1 (Week 7) reviewed. `cheatsheet.md` open only as the exam allows (docs allowed: kubernetes.io/docs, github.com/kubernetes, and other allowed-list sites; nothing else).
- Quiet 2 h block, one browser window/tab set as on exam day, no phone, no notes beyond what the real exam permits.

## Task
1. Start the killer.sh CKS session only when you can run 2 uninterrupted hours. Note the start time.
2. Set up the shell first: `alias k=kubectl`, `export do="--dry-run=client -o yaml"`, `export now="--force --grace-period=0"`.
3. Work as on exam day: read each question fully, run `kubectl config use-context` for the stated context, apply time-boxing (flag and skip anything over 10–12 min), verify each task before moving on.
4. Keep a scratch list: question number, skipped/flagged, time spent, confidence (H/M/L).
5. Stop at 2:00 even if unfinished.
6. Immediately after, open the killer.sh solutions and score each question. For every miss record: question, category (a–e above), root cause, the doc page or command that would have fixed it.
7. Redo each missed question in the live simulator (or on `kind-cks` if reproducible) until it passes without help.
8. Compare with attempt #1: score, time per question, which domains improved.
9. Write the Day 2 target list (max 8 items).

## Check your work
- Full 2 h run completed without pausing or peeking at solutions.
- Every question has a score and a recorded outcome.
- Every miss has a category and a fixed, re-run result.
- A written Day 2 target list exists.

## Answer
[answers/week-08-final-review/day-01-killersh-attempt-2.md](../../answers/week-08-final-review/day-01-killersh-attempt-2.md) — Attempt the task first; only then open the answer.
