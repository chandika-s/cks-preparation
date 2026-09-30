# Week 3 · Day 4 (Oct 10) — seccomp
**Domain:** System Hardening (10%) — Kernel hardening tools (seccomp) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Run pods with the `RuntimeDefault` seccomp profile.
- Author a custom `Localhost` seccomp profile and install it on a node.
- Demonstrate a blocked syscall (`EPERM`) and verify the seccomp mode from inside the container.

## Theory
seccomp (secure computing mode) filters the syscalls a process may make. In Kubernetes it is configured through `securityContext.seccompProfile` at pod or container level (GA since v1.19; the old `seccomp.security.alpha.kubernetes.io/pod` annotation is obsolete).

- **`type: RuntimeDefault`** — the container runtime's default profile (containerd/CRI-O). Blocks dozens of dangerous syscalls (`mount`, `reboot`, `kexec_load`, `bpf`, `unshare` without CAP_SYS_ADMIN, etc.) while allowing normal workloads.
- **`type: Unconfined`** — no filtering (the default for pods unless the kubelet runs with `--seccomp-default`, GA in v1.27).
- **`type: Localhost`** — custom profile file, `localhostProfile: <path relative to kubelet seccomp root>`; the root is `<kubelet root-dir>/seccomp`, i.e. `/var/lib/kubelet/seccomp/` on the node. The file must exist on the node where the pod is scheduled, or the container fails with `CreateContainerError`/`cannot load seccomp profile`. Subdirectories are allowed (`profiles/x.json`).
- **Profile format (JSON):** `defaultAction` plus a `syscalls` list of `{names: [...], action: ...}`. Actions: `SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO` (returns EPERM by default), `SCMP_ACT_KILL`, `SCMP_ACT_LOG` (logs to syslog/audit), `SCMP_ACT_TRACE`. Allow-list style: `defaultAction: SCMP_ACT_ERRNO` + allowed syscalls (strictest, hard to author). Deny-list style: `defaultAction: SCMP_ACT_ALLOW` + blocked syscalls (used here).
- **Verify:** `grep Seccomp /proc/1/status` inside the container: `Seccomp: 2` = filter mode active, `0` = disabled. `Seccomp_filters: N` shows filter count.
- Pod- versus container-level: container-level overrides pod-level.

Kind notes: seccomp works on kind. Node names/containers are `cks-control-plane` and `cks-worker`. Use `nodeName` or `nodeSelector` to ensure the pod lands on the node holding the profile. Behavioural nuance: `RuntimeDefault` itself blocks `unshare` for pods without CAP_SYS_ADMIN, so `unshare` does not distinguish custom from default; use `mkdir` for the contrast and `Unconfined` for `unshare`.

## Prerequisites
none

## Exam-style question
Context: cluster `kind-cks`, namespace `seccomp-lab`, worker node `cks-worker`. Task: apply seccomp to pods as follows. Pod `default-seccomp` must use the runtime default profile; pod `custom-seccomp` (image `busybox`) on `cks-worker` must use a custom node-local profile `profiles/deny-mkdir.json` that allows everything except `unshare`, `mkdir` and `mkdirat`, which must return EPERM; pod `unconfined` must run with no filtering. Requirements: all pods except the one intentionally broken must be `Running` with `sleep 3600`; show that `mkdir /tmp/x` fails in `custom-seccomp` but succeeds in `default-seccomp`; pod `bad-profile` referencing the missing `profiles/missing.json` on `cks-worker` must be created and its failure reason recorded.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Namespace `seccomp-lab` (create it). All pods use image `nginx` unless stated; command `sleep 3600`. Use `busybox` pods where an image with `mkdir` is enough.

1. Create pod `default-seccomp` with `securityContext.seccompProfile.type: RuntimeDefault` (pod level). Confirm it is `Running` and record the `Seccomp:` line from `/proc/1/status`.
2. On node `cks-worker` (`docker exec -it cks-worker bash`) create `/var/lib/kubelet/seccomp/profiles/deny-mkdir.json`. The profile must default to allow and return `EPERM` for the syscalls `unshare`, `mkdir` and `mkdirat`.
3. Create pod `custom-seccomp` (image `busybox`, `sleep 3600`) scheduled on `cks-worker` that references the profile with `type: Localhost` and `localhostProfile: profiles/deny-mkdir.json`.
4. In `custom-seccomp`, run `mkdir /tmp/x` and show it fails with `Operation not permitted`; in `default-seccomp` show `mkdir /tmp/x` succeeds. Show `Seccomp: 2` in both pods.
5. Create pod `unconfined` (`type: Unconfined`, image `nginx`, `sleep 3600`) and pod `custom-nginx` with the custom profile (image `nginx`, on `cks-worker`). Compare `unshare -U true` in all three (`default-seccomp`, `unconfined`, `custom-nginx`) and explain the differences (note the kernel/host may still refuse user namespaces).
6. Create pod `bad-profile` referencing `Localhost` profile `profiles/missing.json` on `cks-worker`; record the resulting pod status and event text.

## Check your work
- `default-seccomp` and `custom-seccomp` are `Running`.
- `kubectl -n seccomp-lab exec custom-seccomp -- mkdir /tmp/x` fails; the same in `default-seccomp` (use `nginx` image, `mkdir` from coreutils) succeeds.
- `grep Seccomp /proc/1/status` prints `Seccomp: 2` in the profiled pods and `0` in `unconfined`.
- `bad-profile` shows an error event mentioning the seccomp profile; it never becomes `Running`.

## Answer
[answers/week-03-system-hardening/day-04-seccomp.md](../../answers/week-03-system-hardening/day-04-seccomp.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns seccomp-lab
```
On `cks-worker`: `rm -rf /var/lib/kubelet/seccomp/profiles`.
