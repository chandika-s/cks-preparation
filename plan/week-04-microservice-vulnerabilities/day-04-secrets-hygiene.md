# Week 4 · Day 4 (Oct 15) — Secrets hygiene
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Convert a Secret consumed via environment variable into a read-only volume mount.
- Verify the Secret value is not embedded in the pod spec.
- Explain the secret handling options and know both the at-rest and in-use protections.

## Theory
- Environment variables are inherited by child processes, appear in `/proc/<pid>/environ`, `kubectl exec ... env`, crash dumps, debug endpoints and some logging. Env values are fixed at container start and never refresh when the Secret changes.
- `env.valueFrom.secretKeyRef` keeps the value out of the pod spec (only the Secret name/key is stored, so `kubectl describe pod` shows `<set to the key ... in secret ...>`); a literal `env.value:` puts plaintext in the spec, which is worse.
- Volume-mounted Secrets are tmpfs-backed (never written to node disk), file mode configurable via `defaultMode`/`items[].mode`, and are updated in place (eventually, ~kubelet sync period) unless mounted with `subPath`. Mount `readOnly: true`. Files appear one per key under `mountPath`.
- Related hardening: `automountServiceAccountToken: false` when API access isn't needed, least-privilege RBAC on `secrets` (avoid `list`/`watch` broadly; `get` on named resources via `resourceNames`), `immutable: true` on Secrets that never change, namespace separation.
- Never commit plaintext or merely base64 Secret manifests to git. Conceptual options: Sealed Secrets (asymmetric, encrypted CRD safe for git), External Secrets Operator (syncs from AWS Secrets Manager/Vault/etc.), HashiCorp Vault (agent injector / CSI driver), Secrets Store CSI Driver, SOPS.
- Secrets are only base64 in etcd until encryption at rest is enabled (Day 3). Know both: at rest (EncryptionConfiguration/KMS) and in use (volumes over env, RBAC).

## Prerequisites
None. (If Day 3 encryption is enabled, that is fine.)

## Exam-style question
Context: namespace `secrets-lab` contains Secret `db-creds` (keys `username` and `password`) consumed by Deployment `app` through the environment variable `DB_PASSWORD`. Task: reconfigure `app` so the password is no longer exposed as an environment variable and is instead available to the container as a read-only file at `/etc/db-creds/password` with mode `0400`. Requirements: the Secret itself must not change, the pod specification must not contain the password value in any form, and the Deployment must remain at 1 running replica.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create namespace `secrets-lab`. Create Secret `db-creds` there with `username=appuser` and `password=S3cr3tPassw0rd`.
2. Create Deployment `app` (1 replica, image `busybox:1.36`, command `sleep 3600`) in `secrets-lab` that injects `password` into env var `DB_PASSWORD` using `secretKeyRef`. Verify from inside the container that `DB_PASSWORD` is visible in the environment.
3. Convert the Deployment so it no longer uses any env var for the Secret. Instead mount `db-creds` as a read-only volume at `/etc/db-creds`, with file mode `0400`.
4. Confirm inside the container that `/etc/db-creds/password` exists and contains the password, and that no `DB_PASSWORD` env var exists.
5. Dump the pod as YAML and prove the password value (plaintext and its base64 form) does not appear anywhere in it; only the Secret's name does.
6. Attempt to write to `/etc/db-creds/password` from the container and record the result.
7. Write down (one line each) three ways to keep Secrets out of git in a real pipeline.

## Check your work
- `kubectl exec -n secrets-lab deploy/app -- env | grep DB_PASSWORD` prints nothing after step 3.
- `kubectl exec -n secrets-lab deploy/app -- cat /etc/db-creds/password` prints `S3cr3tPassw0rd`.
- `kubectl get pod -n secrets-lab -o yaml | grep -ci -e S3cr3tPassw0rd -e UzNjcjN0UGFzc3cwcmQ` prints `0`.
- `ls -lL /etc/db-creds` (dereferencing the symlinks) shows mode `-r--------`, and writes fail with `Read-only file system`.

## Answer
[answers/week-04-microservice-vulnerabilities/day-04-secrets-hygiene.md](../../answers/week-04-microservice-vulnerabilities/day-04-secrets-hygiene.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete namespace `secrets-lab`.
