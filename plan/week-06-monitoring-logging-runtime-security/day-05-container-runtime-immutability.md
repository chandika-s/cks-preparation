# Week 6 · Day 5 (Nov 1) — Ensure immutability of containers at runtime
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Make a running Deployment's containers immutable at runtime.
- Fix the crashes a read-only root filesystem causes with a narrowly scoped writable volume.
- Drop all capabilities and add back only what is required.

## Theory
Immutable containers cannot be modified after start, limiting what an attacker can drop or change.

- `securityContext.readOnlyRootFilesystem: true` (container level): root FS mounted read-only. Apps that write to `/tmp`, cache or pid paths fail unless given a writable volume.
- `allowPrivilegeEscalation: false`: sets `no_new_privs`; blocks setuid binaries and gaining more privileges than the parent.
- `capabilities.drop: ["ALL"]`; then `capabilities.add: [<CAP>]` only if required (for example `NET_BIND_SERVICE` for ports below 1024 when the runtime does not lower `ip_unprivileged_port_start`).
- `runAsNonRoot: true` / `runAsUser`, `seccompProfile.type: RuntimeDefault`, `privileged: false`.
- Avoid `hostPath` volumes; use `emptyDir` only for specific paths the app must write, mounted at the narrowest path (`emptyDir.medium: Memory` optional, with `sizeLimit`).
- `securityContext` fields split between pod level (`runAsUser`, `fsGroup`, `seccompProfile`) and container level (`readOnlyRootFilesystem`, `allowPrivilegeEscalation`, `capabilities`, `privileged`). Container level overrides pod level.
- Pod Security Admission `restricted` requires non-root, no priv-esc, drop ALL, seccomp (it does not require read-only rootfs).
- Verify: `kubectl exec` and try writes; `kubectl get pod -o jsonpath` on `securityContext`; `kubectl logs` for `Read-only file system` errors.

## Prerequisites
none.

## Task
1. Create namespace `immutable` and Deployment `web` (1 replica) with image `nginxinc/nginx-unprivileged:1.27-alpine`, container port 8080, no securityContext. Wait for it to be ready.
2. Edit the Deployment so the container `web` has `readOnlyRootFilesystem: true`. Observe the rollout: find out why the new pod fails (logs) and record the path.
3. Fix the failure with an `emptyDir` volume named `tmp` mounted only at `/tmp` in container `web`.
4. Also set on container `web`: `allowPrivilegeEscalation: false` and `capabilities.drop: ["ALL"]`. Add no capabilities unless the pod fails without them; state whether any were needed.
5. Also set pod-level `runAsNonRoot: true` and `seccompProfile.type: RuntimeDefault`.
6. Exec into the new pod:
   - `touch /newfile` must fail.
   - `touch /tmp/ok` must succeed.
   - Show that the process capability set is empty (check `CapEff` in `/proc/1/status`).
7. Confirm the Deployment rolled out successfully and serves HTTP on 8080 (from inside the pod).

## Check your work
- Step 2 pod is in `CrashLoopBackOff`/`Error`; logs mention `Read-only file system` and a path under `/tmp`.
- Final pod is `Running` `1/1`; `touch /newfile` prints `Read-only file system`; `touch /tmp/ok` succeeds.
- `CapEff:` shows `0000000000000000`.
- `kubectl get deploy web -n immutable` shows `1/1` available.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-05-container-runtime-immutability.md](../../answers/week-06-monitoring-logging-runtime-security/day-05-container-runtime-immutability.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns immutable`
