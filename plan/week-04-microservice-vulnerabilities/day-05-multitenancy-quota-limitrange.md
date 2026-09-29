# Week 4 · Day 5 (Oct 16) — Isolation: multi-tenancy with quotas and limits
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Explain the layers that make up namespace-level multi-tenancy.
- Write a `ResourceQuota` and a `LimitRange` for a tenant namespace.
- Trigger and read the quota and limit-range rejection messages.

## Theory
Namespace-based soft multi-tenancy combines:
- RBAC (Week 2): each tenant only gets Roles/RoleBindings in its own namespace.
- NetworkPolicy (Week 1): default-deny per namespace, allow only intended traffic (Kubernetes is flat by default).
- PSA (Days 1–2): per-namespace `restricted` level.
- `ResourceQuota`: caps aggregate consumption per namespace (compute `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory`; object counts `pods`, `secrets`, `services`, `persistentvolumeclaims`; storage `requests.storage`). Prevents noisy-neighbour/DoS.
- `LimitRange`: per-Pod/Container/PVC `default` (limit), `defaultRequest`, `min`, `max`, `maxLimitRequestRatio`. Injects defaults at admission and rejects out-of-range specs.

Behaviour to know:
- If a quota covers `cpu`/`memory` requests or limits, every new Pod must specify them, or creation is rejected (`must specify limits.cpu ...`). A LimitRange with defaults injects them so pods without explicit values are admitted.
- Both are enforced at admission time (LimitRanger runs before ResourceQuota). Existing pods are unaffected.
- When quota is exhausted through a Deployment, the Deployment/ReplicaSet is accepted but Pods fail: look in `kubectl describe rs` / events for `FailedCreate ... exceeded quota`. Bare Pods fail immediately on `kubectl run`.
- Inspect: `kubectl describe quota -n <ns>` (Used vs Hard), `kubectl describe limitrange -n <ns>`.
- Imperative: `kubectl create quota <name> --hard=pods=3,requests.cpu=1 -n <ns>`. There is no imperative LimitRange; write YAML.
- For stronger isolation than namespaces, use separate node pools (taints/tolerations, nodeSelector), sandboxed runtimes (Day 6) or separate clusters.

## Prerequisites
None.

## Task
1. Create namespaces `tenant-a` and `tenant-b`.
2. In `tenant-a` create `ResourceQuota` `tenant-a-quota` with hard limits:
   - `pods: 3`
   - `requests.cpu: 1`, `requests.memory: 1Gi`
   - `limits.cpu: 2`, `limits.memory: 2Gi`
3. In `tenant-a` create `LimitRange` `tenant-a-limits` for type `Container`:
   - default limits: cpu `200m`, memory `128Mi`
   - default requests: cpu `100m`, memory `64Mi`
   - maximum per container: cpu `500m`, memory `512Mi`
4. Create Deployment `web` (image `nginx:1.27`, no explicit resources) with 5 replicas in `tenant-a`. Observe how many pods run, find and record the exact quota error in the ReplicaSet events, and confirm the defaults from the LimitRange were injected into a running pod.
5. Create a bare Pod `hog` in `tenant-a` (image `nginx:1.27`) whose container sets `limits.cpu: 1`. Record the exact rejection message and explain which object produced it.
6. Confirm `tenant-b` has no such limits by running 5 replicas of the same Deployment there (all Running).
7. Show the current quota usage in `tenant-a` with a single command.

## Check your work
- `kubectl get pods -n tenant-a` shows exactly 3 pods; ReplicaSet shows 3/5 ready with `FailedCreate ... exceeded quota: tenant-a-quota`.
- A running `tenant-a` pod shows `Limits: cpu 200m, memory 128Mi` and `Requests: cpu 100m, memory 64Mi` although the Deployment sets none.
- `hog` is rejected with a `maximum cpu usage per Container is 500m, but limit is 1` style message.
- `tenant-b` runs 5/5 pods.
- `kubectl describe quota tenant-a-quota -n tenant-a` shows `pods 3/3`.

## Answer
[answers/week-04-microservice-vulnerabilities/day-05-multitenancy-quota-limitrange.md](../../answers/week-04-microservice-vulnerabilities/day-05-multitenancy-quota-limitrange.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete namespaces `tenant-a` and `tenant-b`.
