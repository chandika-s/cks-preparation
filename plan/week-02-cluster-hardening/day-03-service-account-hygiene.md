# Week 2 · Day 3 (Oct 2) — Service account hygiene
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Disable automatic API token mounting for the `default` ServiceAccount.
- Use dedicated ServiceAccounts per workload, granting token access only where needed.
- Prove the behaviour from inside pods.

## Theory
- Every namespace has a `default` ServiceAccount. Pods that do not set `serviceAccountName` use it, and by default a projected token is mounted at `/var/run/secrets/kubernetes.io/serviceaccount` (`token`, `ca.crt`, `namespace`). A compromised container can then call the API with that identity.
- Since v1.24 tokens are bound, time-limited, projected volumes (audience/pod-bound); no long-lived Secret is auto-created. Long-lived tokens exist only if you create a `kubernetes.io/service-account-token` Secret explicitly.
- Controls: `automountServiceAccountToken: false` on the ServiceAccount (default for pods using it) or on the pod spec. The pod spec value wins over the SA value. Changes to a ServiceAccount affect only pods created afterwards.
- Best practice: dedicated SA per workload; least-privilege RBAC on it; `automountServiceAccountToken: false` unless the app calls the API; do not bind roles to `default`.
- Useful: `kubectl create serviceaccount`, `kubectl patch serviceaccount default -p '{"automountServiceAccountToken": false}'`, `kubectl create token <sa>` (short-lived on demand), `kubectl get pod -o jsonpath='{.spec.serviceAccountName}'`, `kubectl exec ... -- ls /var/run/secrets/kubernetes.io/serviceaccount`.
- Also `kubectl get pods -A -o json | jq` for `.spec.serviceAccountName` and `.spec.automountServiceAccountToken` to audit.

## Prerequisites
None.

## Task
1. Create namespace `sa-lab`.
2. Set `automountServiceAccountToken: false` on the `default` ServiceAccount in `sa-lab`.
3. Create ServiceAccount `app-sa` in `sa-lab` with `automountServiceAccountToken: true`.
4. Create two Deployments in `sa-lab`, each 1 replica, image `busybox:1.36`, command `sleep 3600`:
   - `no-api` using no explicit ServiceAccount (so `default`).
   - `needs-api` using ServiceAccount `app-sa`.
5. Exec into the `no-api` pod and show `/var/run/secrets/kubernetes.io/serviceaccount` does not exist.
6. Exec into the `needs-api` pod and show the directory exists and contains `token`, `ca.crt`, `namespace`.
7. Demonstrate override precedence: create a pod `override-pod` (busybox:1.36, `sleep 3600`) using `app-sa` but with `automountServiceAccountToken: false` in its own spec, and show that no token is mounted.
8. Audit: list every pod in `sa-lab` with its serviceAccountName and whether the token is mounted (from the spec).

## Check your work
- `kubectl get sa default -n sa-lab -o yaml` shows `automountServiceAccountToken: false`.
- `ls` in the `no-api` pod fails with "No such file or directory".
- `ls` in the `needs-api` pod lists `ca.crt namespace token`.
- `override-pod` has no serviceaccount directory although it uses `app-sa`.
- Pods created before the default SA change (if any) still had a token: understand why.

## Answer
[answers/week-02-cluster-hardening/day-03-service-account-hygiene.md](../../answers/week-02-cluster-hardening/day-03-service-account-hygiene.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns sa-lab` when done.
