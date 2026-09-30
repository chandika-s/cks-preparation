# Week 2 · Day 1 (Sep 30) — RBAC: Role & RoleBinding
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Create a namespace-scoped `Role` and bind it to a ServiceAccount with a `RoleBinding`.
- Apply least privilege: only the verbs and resources actually required.
- Verify effective permissions with `kubectl auth can-i` and impersonation.

## Theory
- RBAC is additive only: there are no deny rules. A subject gets the union of all rules from all bindings that match it.
- `Role` / `RoleBinding`: namespace-scoped. `ClusterRole` / `ClusterRoleBinding`: cluster-scoped. A `RoleBinding` may reference a `ClusterRole`; the permissions then apply only inside the RoleBinding's namespace (reusable role template).
- A Role rule has `apiGroups`, `resources`, `verbs` (optionally `resourceNames`, `nonResourceURLs` for ClusterRoles). Core group is `""`. Subresources are written `pods/log`, `pods/exec`.
- Verbs: `get, list, watch, create, update, patch, delete, deletecollection`, plus special `bind`, `escalate`, `impersonate`. `list`/`watch` on secrets exposes secret contents.
- Subject kinds: `User`, `Group`, `ServiceAccount`. SA username form: `system:serviceaccount:<ns>:<name>`.
- `roleRef` is immutable on a binding; delete and recreate to change it.
- Key commands: `kubectl create role`, `kubectl create rolebinding --role= --serviceaccount=<ns>:<sa>`, `kubectl auth can-i <verb> <resource> --as=<user> -n <ns>`, `kubectl auth can-i --list`.
- Imperative scaffold: append `--dry-run=client -o yaml`.

## Prerequisites
None (kind-cks running, `kubectl config current-context` is `kind-cks`).

## Exam-style question
Context: the kind-cks cluster is available and namespace `rbac-lab` does not exist yet. Task: create namespace `rbac-lab` and give ServiceAccount `pod-reader-sa` read-only access to pods in that namespace only, using a Role named `pod-reader` and a RoleBinding named `pod-reader-binding`. Requirements: grant nothing beyond get, list and watch on pods; the ServiceAccount must have no access to pods in other namespaces, to secrets, or to delete pods. Prove the result with `kubectl auth can-i` impersonation.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create namespace `rbac-lab` and a ServiceAccount `pod-reader-sa` in it.
2. Create a Role `pod-reader` in `rbac-lab` that allows only `get`, `list`, `watch` on `pods` (core API group, no subresources).
3. Create a RoleBinding `pod-reader-binding` in `rbac-lab` that binds Role `pod-reader` to ServiceAccount `pod-reader-sa`.
4. Verify by impersonating `system:serviceaccount:rbac-lab:pod-reader-sa` with `kubectl auth can-i`:
   - `list pods` in `rbac-lab` must be `yes`.
   - `delete pods` in `rbac-lab` must be `no`.
   - `list pods` in namespace `default` must be `no`.
   - `get secrets` in `rbac-lab` must be `no`.
5. Print the effective permission list of the ServiceAccount in `rbac-lab` and confirm no verbs beyond those requested.

## Check your work
- `kubectl get role,rolebinding,sa -n rbac-lab` shows `pod-reader`, `pod-reader-binding`, `pod-reader-sa`.
- `kubectl describe role pod-reader -n rbac-lab` shows exactly one rule: `pods` with `[get list watch]`.
- `kubectl describe rolebinding pod-reader-binding -n rbac-lab` shows Role/pod-reader and subject kind ServiceAccount, name `pod-reader-sa`, namespace `rbac-lab`.
- The four `can-i` answers are yes / no / no / no.

## Answer
[answers/week-02-cluster-hardening/day-01-rbac-role-rolebinding.md](../../answers/week-02-cluster-hardening/day-01-rbac-role-rolebinding.md) — Attempt the task first; only then open the answer.

## Cleanup
Keep `rbac-lab` until end of week if convenient; otherwise `kubectl delete ns rbac-lab`.
