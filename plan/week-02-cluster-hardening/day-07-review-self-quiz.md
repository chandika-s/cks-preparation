# Week 2 · Day 7 (Oct 6) — Review & self-quiz
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Reproduce the week's core skills from memory, under time limits.
- Explain the reasoning behind SA hygiene and API server hardening.
- Recall the kubeadm upgrade sequence without references.

## Theory
Review only after attempting: RBAC scoping (Role vs ClusterRole, bindings, imperative commands), `cluster-admin` auditing via jq, `automountServiceAccountToken` (SA vs pod precedence, new pods only), apiserver flags (`--anonymous-auth`, `--profiling`, `--authorization-mode`, `NodeRestriction`, no insecure port), kubeadm order (control plane, then workers; one minor at a time; drain/uncordon; `upgrade apply` vs `upgrade node`). Do not open `cheatsheet.md` or the kubernetes.io docs during the timed items; use `kubectl create ... --help` at most.

## Prerequisites
None. Use scratch namespace `quiz-rbac` (create it as part of item 1).

## Task
Do items 1–2 as timed hands-on tasks; answer 3–5 in writing (put them in `workspace/week02-quiz.md`) from memory.
1. (8 min) Create namespace `quiz-rbac`, ServiceAccount `viewer`, a Role and RoleBinding scoping `viewer` to read-only (`get,list,watch`) access to `pods` in that namespace. Prove allowed and denied actions with `kubectl auth can-i`.
2. (5 min) Find all `cluster-admin` ClusterRoleBindings in the cluster, showing name and subjects. State which are expected.
3. (5 min) Write out how you would disable `default` SA token auto-mount across a cluster, namespace by namespace, and explain why per-namespace handling is needed (what is not covered, what overrides it, what existing pods do).
4. (5 min) List the kube-apiserver flags/plugins you would check or fix for hardening, and what each does.
5. (5 min) Write the kubeadm upgrade sequence for a 2-node cluster (one control plane, one worker) from memory, including where each command runs.

## Check your work
- Item 1: yes for get/list/watch pods in `quiz-rbac`; no for delete pods, no for pods in `default`, no for secrets.
- Item 2: the two built-in bindings are found and named; you can say why each is expected.
- Item 3 mentions: there is no cluster-wide switch; each namespace has its own `default` SA; new namespaces need it again; pod-level field overrides; existing pods need restart; dedicated SAs for workloads that need API.
- Item 4 covers at least: anonymous-auth, profiling, authorization-mode, NodeRestriction, insecure port removed, token-auth-file absent, kubelet CA/TLS settings, audit logging, encryption at rest.
- Item 5 lists: unhold/install kubeadm, plan, apply, drain, kubelet/kubectl upgrade, restart kubelet, uncordon; worker: drain, kubeadm, `upgrade node`, kubelet, restart, uncordon.

## Answer
[answers/week-02-cluster-hardening/day-07-review-self-quiz.md](../../answers/week-02-cluster-hardening/day-07-review-self-quiz.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns quiz-rbac`
