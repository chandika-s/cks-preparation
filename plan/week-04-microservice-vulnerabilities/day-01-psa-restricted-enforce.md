# Week 4 · Day 1 (Oct 12) — Pod Security Standards: enforcing `restricted`
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Enforce the `restricted` Pod Security Standard on a namespace with labels.
- Read and interpret a PSA violation message.
- Make a non-compliant pod compliant with the minimum required `securityContext` fields.

## Theory
Pod Security Admission (PSA) is a built-in admission controller (enabled by default, GA since v1.25) that replaced PodSecurityPolicy (removed in v1.25). It evaluates pods against the Pod Security Standards (PSS).

Levels:
- `privileged` — unrestricted.
- `baseline` — blocks known privilege escalations: privileged containers, hostNetwork/hostPID/hostIPC, hostPath volumes, hostPort, most added capabilities, unconfined seccomp/AppArmor overrides, custom SELinux types, unsafe sysctls.
- `restricted` — baseline plus hardening best practice: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]` (only `NET_BIND_SERVICE` may be added back), `seccompProfile.type` of `RuntimeDefault` or `Localhost`, no running as UID 0, restricted volume types only (configMap, csi, downwardAPI, emptyDir, ephemeral, persistentVolumeClaim, projected, secret).

Modes (each is a namespace label, `pod-security.kubernetes.io/<mode>=<level>`):
- `enforce` — reject the pod.
- `audit` — allow, add an audit-log annotation.
- `warn` — allow, return a warning to the client.

Optional version pin: `pod-security.kubernetes.io/<mode>-version=v1.35` (default `latest`).

Key points:
- Enforcement applies to Pod creation/update. Workload objects (Deployment, etc.) are admitted, but their pods are rejected; the error shows up in ReplicaSet events, not on `kubectl apply`. Use `warn` alongside `enforce` to get feedback at apply time.
- Existing running pods are not evicted when a label is added.
- Preview the impact of a label: `kubectl label --dry-run=server --overwrite ns <ns> pod-security.kubernetes.io/enforce=restricted` (emits warnings for existing violating pods).
- Cluster-wide defaults/exemptions are configured via `AdmissionConfiguration` for the `PodSecurity` plugin passed to the API server (`--admission-control-config-file`); namespaces such as `kube-system` are typically exempt.

## Prerequisites
None.

## Task
1. Set context `kind-cks`. Create namespace `psa-lab`.
2. Label `psa-lab` so that the `restricted` level is enforced (latest version).
3. Create a pod `root-pod` in `psa-lab` using image `busybox:1.36`, command `sleep 3600`, with no `securityContext` at all. Confirm the API server rejects it. Record the full violation message and list every distinct violation it names.
4. Write a manifest `~/psa-lab/ok-pod.yaml` for pod `ok-pod` in `psa-lab` (image `busybox:1.36`, command `sleep 3600`) that satisfies `restricted`:
   - runs as a non-root user (UID 1000),
   - cannot escalate privileges,
   - drops all capabilities,
   - uses the runtime default seccomp profile.
5. Apply it and confirm the pod reaches `Running`.
6. Additionally label the namespace with `warn` and `audit` set to `restricted`, then confirm that creating a `baseline`-violating pod (e.g. `privileged: true`) named `priv-pod` is rejected with a message mentioning the `restricted` policy.

## Check your work
- Step 3 fails with `Error from server (Forbidden)` mentioning `violates PodSecurity "restricted:latest"` and naming at least: allowPrivilegeEscalation, capabilities, runAsNonRoot, seccompProfile.
- `kubectl get pod ok-pod -n psa-lab` shows `Running`.
- `kubectl get ns psa-lab --show-labels` lists `enforce`, `warn` and `audit` labels set to `restricted`.
- `kubectl get pod root-pod -n psa-lab` returns NotFound.

## Answer
[answers/week-04-microservice-vulnerabilities/day-01-psa-restricted-enforce.md](../../answers/week-04-microservice-vulnerabilities/day-01-psa-restricted-enforce.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete namespace `psa-lab` when done.
