# Week 2 · Day 6 (Oct 5) — Combined RBAC + SA audit task
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Remove an over-privileged binding and replace it with least privilege.
- Move a workload to a dedicated ServiceAccount and disable default SA token automount.
- Prove the result with `kubectl auth can-i`. Complete in 20 minutes.

## Theory
- Review Days 1–3: Role/RoleBinding scoping, `cluster-admin` audit, `automountServiceAccountToken`.
- Remediation order: identify the offending binding (`kubectl get rolebindings,clusterrolebindings -A -o wide`, check `subjects`), remove it, create the least-privilege role, create the dedicated SA, update the workload (`kubectl set serviceaccount` or edit the pod template), roll out, verify.
- A RoleBinding may reference the `cluster-admin` ClusterRole; it then grants full rights inside that namespace only, but that is still severe (all secrets there).
- `list`/`get` on `secrets` exposes secret data; only grant it when the requirement says so.
- Changing a Deployment's pod template triggers a rollout; changing an SA field does not affect existing pods.
- Verification: `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>`.

## Prerequisites
None. Create the scenario with the setup below (part of the exam-style question, not the solution).

Setup:
```
kubectl create namespace payments
kubectl create deployment payments-api --image=nginx:1.27 -n payments
kubectl create rolebinding payments-admin --clusterrole=cluster-admin --serviceaccount=payments:default -n payments
kubectl create configmap app-config --from-literal=mode=prod -n payments
kubectl create secret generic app-secret --from-literal=k=v -n payments
```

## Task
Timed: 20 minutes.
Namespace `payments` has Deployment `payments-api` running as the `default` ServiceAccount, and `default` has `cluster-admin` bound through a stray RoleBinding. Fix it:
1. Identify and delete the over-privileged RoleBinding (find it by inspection; do not delete anything else).
2. Create Role `payments-reader` in `payments` allowing only `get` and `list` on `configmaps` and `secrets`.
3. Create ServiceAccount `payments-sa` in `payments` and bind `payments-reader` to it with RoleBinding `payments-reader-binding`.
4. Change Deployment `payments-api` to run as `payments-sa`, and make sure the rollout completes.
5. Set `automountServiceAccountToken: false` on the `default` ServiceAccount in `payments`.
6. Prove with `kubectl auth can-i` (as `system:serviceaccount:payments:...`):
   - `payments-sa`: `list configmaps` yes, `get secrets` yes, `delete secrets` no, `list pods` no, `list configmaps -n default` no.
   - `default`: `list secrets` no, `delete deployments` no.

## Check your work
- No RoleBinding in `payments` references `cluster-admin`.
- `kubectl get deploy payments-api -n payments -o jsonpath='{.spec.template.spec.serviceAccountName}'` prints `payments-sa` and the new pod is Running.
- `kubectl get sa default -n payments -o yaml` shows `automountServiceAccountToken: false`.
- All seven can-i answers match the expected yes/no values.

## Answer
[answers/week-02-cluster-hardening/day-06-rbac-sa-audit-timed.md](../../answers/week-02-cluster-hardening/day-06-rbac-sa-audit-timed.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns payments`
