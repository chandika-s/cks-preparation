# Week 8 · Day 4 (Nov 15) — Exam day
**Domain:** All domains (CKS exam) | **Est. time:** 2 h exam + check-in | **Cluster:** exam clusters (not kind-cks)

## Objectives
- Sit and pass the CKS exam.
- Execute the runbook: safe context switching, time-boxing, verification.
- Passing also extends your CKA expiration (see `00-exam-and-cka-renewal.md`).

## Theory
- Performance-based, 2 hours, Kubernetes v1.35, multiple clusters; each task states its context. Wrong context = zero credit and possible damage elsewhere.
- Tasks carry different weights; the scoring is per task with partial credit.
- Key habits: `kubectl config use-context <name>` before every task, read the whole question, verify after every change, flag and skip anything taking more than 10–12 min.
- Allowed documentation: kubernetes.io/docs and other allow-listed sites only (e.g. Falco, Trivy, AppArmor docs as listed in the candidate handbook).

## Prerequisites
- Day 3 checklist complete, slept normally.

## Task
Runbook, in order:
1. (Optional, max 10 min, early morning) One warm-up: a NetworkPolicy or RBAC task on `kind-cks`. Nothing new.
2. Log in early (about 30 min before the slot); run the system check again; have ID ready for check-in.
3. Proctor check-in: room scan, ID, desk clear.
4. First 2 minutes in the terminal: `alias k=kubectl`, `export do="--dry-run=client -o yaml"`, `export now="--force --grace-period=0"`; confirm vim/tmux behaviour.
5. Skim all questions and note weights; order: quick high-weight first, long ones later.
6. For each task: `kubectl config use-context <given>` -> read fully -> do -> verify -> note done.
7. If a task exceeds 10–12 min: flag, move on, return at the end.
8. Reserve the last 10–15 min to revisit flagged tasks and re-verify risky ones (kube-apiserver edits, files saved, pods Running).
9. Submit/end the exam only after the last verification pass.

## Check your work
- Each completed task has a recorded verification (command output matching the requirement).
- The context was set before every task.
- No flagged task left untouched without at least a partial attempt.

## Answer
[answers/week-08-final-review/day-04-exam-day.md](../../answers/week-08-final-review/day-04-exam-day.md) — Attempt the task first; only then open the answer.
