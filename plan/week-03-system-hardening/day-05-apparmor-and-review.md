# Week 3 · Day 5 (Oct 11) — AppArmor + review
**Domain:** System Hardening (10%) — Kernel hardening tools (AppArmor) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Write, load and apply an AppArmor profile to a container.
- Recite the AppArmor pod syntax (annotation and GA field) and where the profile must exist.
- Complete the Week 3 self-quiz without notes.

## Theory
AppArmor is a Linux Security Module (LSM) that confines a program to a profile: file access, capabilities, network, mounts. Modes: `enforce` (violations denied and logged) and `complain` (logged only).

- **Profile:** text file, typically `/etc/apparmor.d/<file>`; the name that matters to Kubernetes is the profile name in the header (`profile <name> flags=(...) { ... }`), not the filename. Rules: `file,` (all file access), `deny /tmp/** w,` (deny writes; deny overrides allows), `capability,`, `network,`. Load/replace: `apparmor_parser -q /path/profile` (`-r` reload, `-R` remove). Inspect: `aa-status` (or `cat /sys/kernel/security/apparmor/profiles`), and `/sys/module/apparmor/parameters/enabled` (`Y`).
- **Kubernetes (older API, still in the CKS curriculum):** pod annotation `container.apparmor.security.beta.kubernetes.io/<container-name>: <value>`, where value is `runtime/default`, `unconfined`, or `localhost/<profile-name>`. The container name in the key must match the container in the pod.
- **Kubernetes (GA since v1.30):** `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <profile-name>}` at pod or container level; `type` is `RuntimeDefault`, `Unconfined`, or `Localhost`. The annotations are deprecated. Know both.
- **Where the profile must exist:** loaded into the kernel of the node that runs the pod (not the control plane, not in the pod). Use `nodeName`/`nodeSelector` or load it on all nodes. If the profile is not loaded, the container fails to start (`CreateContainerError` / pod blocked with a message such as "cannot enforce AppArmor: profile ... is not loaded").
- **Verify in a container:** `cat /proc/1/attr/current` prints `<profile> (enforce)`.

Kind/macOS caveat: per `SETUP.md`, the Docker Desktop LinuxKit VM has no AppArmor, so `aa-status` and `apparmor_parser` are likely unavailable and the pod would be rejected. If `aa-status` fails or `/sys/module/apparmor/parameters/enabled` is missing, do steps 1–3 as a written walkthrough you can recite, and repeat hands-on during the Week 7 killer.sh simulation, which has AppArmor.

## Prerequisites
none (check AppArmor availability first: `docker exec -it cks-worker bash -c 'aa-status; cat /sys/module/apparmor/parameters/enabled'`)

## Exam-style question
Context: cluster `kind-cks`, worker node `cks-worker`, namespace `default`. Task: confine a container with AppArmor. Create and load a profile named `k8s-deny-tmp-write` that allows general file access, capabilities and network but denies writes under `/tmp`, then run pod `aa-test` (image `busybox`, container `main`, `sleep 3600`) on `cks-worker` enforcing it. Requirements: the profile must be loaded on the node that runs the pod; `touch /tmp/x` must fail inside the container while `touch /root/x` succeeds; also provide pod `aa-test-ga` using the current securityContext field instead of the annotation, and record what happens to pod `aa-missing` referencing the unloaded profile `does-not-exist`.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Part A — AppArmor lab on node `cks-worker` (walkthrough only if AppArmor is unavailable):

1. Write profile `k8s-deny-tmp-write` (profile name and file `/etc/apparmor.d/k8s-deny-tmp-write`) that allows general file access, capabilities and network but denies writes anywhere under `/tmp`.
2. Load the profile on the node with `apparmor_parser` and confirm it shows in `aa-status` as enforce mode.
3. Create pod `aa-test` in namespace `default` (image `busybox`, container name `main`, `sleep 3600`) pinned to `cks-worker`, applying the profile using the annotation form. Then recreate it as `aa-test-ga` using the `securityContext.appArmorProfile` form.
4. Confirm `touch /tmp/x` fails inside the container while `touch /root/x` succeeds. Confirm `/proc/1/attr/current`.
5. Create a pod `aa-missing` that references profile `does-not-exist` and record what happens.

Part B — Review self-quiz (timed, no notes, 5 minutes each):

1. Name 3 concrete OS-level hardening actions and state why each reduces attack surface.
2. Write from memory a pod spec fragment that references a seccomp `Localhost` profile `profiles/audit.json`, and one for `RuntimeDefault`.
3. Explain the AppArmor annotation syntax and where the profile must exist for it to apply. Give both the annotation and the GA field form.

## Check your work
- Part A: `aa-status` lists `k8s-deny-tmp-write`; `touch /tmp/x` returns `Permission denied`, `touch /root/x` succeeds; `cat /proc/1/attr/current` shows `k8s-deny-tmp-write (enforce)`.
- Part B: compare your answers against the answer file only after finishing all three, and mark gaps to revise.

## Answer
[answers/week-03-system-hardening/day-05-apparmor-and-review.md](../../answers/week-03-system-hardening/day-05-apparmor-and-review.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete pod aa-test aa-test-ga aa-missing --ignore-not-found
```
On the node: `apparmor_parser -R /etc/apparmor.d/k8s-deny-tmp-write; rm /etc/apparmor.d/k8s-deny-tmp-write`.
