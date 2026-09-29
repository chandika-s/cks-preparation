# Week 4 · Day 8 (Oct 19) — Review & self-quiz
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Reproduce Week 4 tasks from memory under time limits.
- Identify gaps in PSA, encryption at rest, quota/limits, RuntimeClass and pod-to-pod encryption.

## Theory
Week 4 recap, the commands and fields to have memorised:
- PSA: label `pod-security.kubernetes.io/{enforce,audit,warn}=<privileged|baseline|restricted>`; restricted needs `runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, and restricted volume types.
- Encryption at rest: `EncryptionConfiguration` (`aescbc`/`secretbox`, `identity` fallback, first provider writes), `--encryption-provider-config`, hostPath volume + mount in the static pod, verify with `etcdctl get /registry/secrets/<ns>/<name>` (prefix `k8s:enc:aescbc:v1:`), rewrite with `kubectl get secrets -A -o json | kubectl replace -f -`.
- Secrets hygiene: volumes over env, readOnly mounts, RBAC, external secret stores.
- Tenancy: ResourceQuota (`hard`) + LimitRange (`default`, `defaultRequest`, `max`) + RBAC + NetworkPolicy.
- Sandboxing: `RuntimeClass` (`handler`), `runtimeClassName`, containerd runtime registration.
- Pod-to-pod encryption: CNI (WireGuard/IPsec, L3, node identity) vs mesh mTLS (sidecar, per-workload identity, `PeerAuthentication STRICT`).

## Prerequisites
- Cluster `kind-cks` running.
- If Day 3 encryption is still enabled, revert it first using the Cleanup section of the Day 3 answer, so item 2 starts from a plain cluster. (Do this before starting the clock.)
- Do not open earlier answer files while attempting.

## Task
Attempt each item from memory, timed. Use only `kubectl explain`, `--help` and the cheatsheet allowed in the exam (kubernetes.io docs are permitted in the real exam; here try without first, then check the docs).

1. (10 min) Create namespace `quiz-psa` enforcing `restricted`. Create pod `bad` (image `busybox:1.36`, `sleep 3600`, no securityContext), confirm the rejection, then create pod `good` from a fixed manifest that is admitted and Running.
2. (20 min) Enable Secrets encryption at rest end-to-end: `EncryptionConfiguration` with `aescbc` key `qkey1` and `identity` fallback at `/etc/kubernetes/enc/enc.yaml`, the `--encryption-provider-config` flag, the volume and volumeMount on the static pod. Create Secret `quiz-secret` (`k=v1`) and verify ciphertext in etcd. State the prefix you see.
3. (10 min) For a new namespace `quiz-tenant`, write a ResourceQuota (pods 2, requests.cpu 500m, requests.memory 512Mi, limits.cpu 1, limits.memory 1Gi) and a LimitRange (container default limit cpu 250m / memory 256Mi, default request cpu 100m / memory 128Mi, max cpu 500m / memory 512Mi). Demonstrate that a third pod is rejected.
4. (5 min) Write a RuntimeClass `kata` with handler `kata` and a pod `sandboxed` (image `nginx:1.27`) in namespace `default` that uses it. Say in one sentence why it will not run on `kind-cks` and what would make it run.
5. (5 min) Explain, in five sentences or fewer, Pod-to-Pod encryption options and their trade-offs (CNI-level vs mesh mTLS) and name the Istio object for strict mTLS.

Self-scoring: items 1–4 must produce the observable states listed below; item 5 must cover layer, identity, app changes, trade-offs.

## Check your work
- Item 1: `bad` rejected with `violates PodSecurity "restricted:latest"`; `good` Running.
- Item 2: etcd value for `quiz-secret` starts with `k8s:enc:aescbc:v1:qkey1:` and the stored bytes are unreadable ciphertext; API returns the decoded value.
- Item 3: pods `p1`, `p2` run, third pod fails with `exceeded quota: ... limited: pods=2`.
- Item 4: `kubectl get runtimeclass kata` shows handler `kata`; the pod is `ContainerCreating` with a sandbox/no-runtime error (or the RuntimeClass exists and the answer states the missing containerd `kata` runtime).
- Item 5: mentions L3 node-level vs L4/L7 per-workload, no app changes, `PeerAuthentication` `STRICT`.

## Answer
[answers/week-04-microservice-vulnerabilities/day-08-review-self-quiz.md](../../answers/week-04-microservice-vulnerabilities/day-08-review-self-quiz.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete namespaces `quiz-psa` and `quiz-tenant`, pod `sandboxed` and RuntimeClass `kata`. Revert encryption as described in the Day 3 answer if you do not want it enabled going into Week 5.
