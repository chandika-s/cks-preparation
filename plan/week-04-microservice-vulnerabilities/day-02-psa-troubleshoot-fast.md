# Week 4 · Day 2 (Oct 13) — Troubleshooting PSA + writing compliant specs fast
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Diagnose why a Deployment's pods are not created in a `restricted` namespace.
- Fix all violations in a single pass within 15 minutes.
- Memorise the compliant `securityContext` skeleton and restricted volume types.

## Theory
Troubleshooting flow when a workload "does nothing" in a PSA-enforced namespace:
1. `kubectl get deploy,rs,pods -n <ns>` — Deployment exists, ReplicaSet shows `DESIRED > CURRENT`, no pods.
2. `kubectl describe rs -n <ns>` or `kubectl get events -n <ns> --sort-by=.lastTimestamp` — a `FailedCreate` event carries the full `violates PodSecurity "restricted:latest": ...` message listing every violation at once (fix them all in one pass).
3. Dry-run against the server to iterate quickly: `kubectl apply --dry-run=server -f file.yaml` (Deployments only warn; a bare Pod is rejected outright). With a `warn` label present, warnings print at apply time for Deployments too.

Common restricted-level violations and fixes:
- Runs as root → `runAsNonRoot: true` and a numeric `runAsUser` (non-zero).
- `privileged: true` → remove it (also implies escalation); set `allowPrivilegeEscalation: false`.
- Capabilities → `drop: ["ALL"]` (only `NET_BIND_SERVICE` allowed back via `add`).
- No seccomp → `seccompProfile.type: RuntimeDefault`.
- Disallowed volume (`hostPath`, `nfs`, etc.) → replace with `emptyDir`, `configMap`, `secret`, `projected`, `downwardAPI`, `persistentVolumeClaim`, `ephemeral` or `csi`.
- Host namespaces / hostPort → remove `hostNetwork`, `hostPID`, `hostIPC`, `hostPort`.
- Fix the Deployment's pod template (`spec.template.spec`), not just a running pod.

## Prerequisites
None (Day 1 concepts).

## Task
Time limit: 15 minutes.

1. Create namespace `psa-fast` enforcing `restricted`.
2. Save the following manifest as `~/psa-fast/broken.yaml` and apply it:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logger
  namespace: psa-fast
spec:
  replicas: 2
  selector:
    matchLabels:
      app: logger
  template:
    metadata:
      labels:
        app: logger
    spec:
      containers:
      - name: logger
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /host-logs/out.log; sleep 5; done"]
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: logs
          mountPath: /host-logs
      volumes:
      - name: logs
        hostPath:
          path: /var/log
```
3. Without deleting the Deployment, find from cluster events why no pods exist. List every violation reported.
4. Fix the manifest (saved as `~/psa-fast/fixed.yaml`) so that:
   - the container does not run as root and is not privileged,
   - no hostPath volume is used; the container still has a writable `/host-logs` path backed by non-persistent storage,
   - the seccomp profile is `RuntimeDefault`,
   - it satisfies every other `restricted` requirement.
   Apply it so both replicas run.
5. The container must still write `/host-logs/out.log` successfully.

## Check your work
- Step 3 events show violations covering: allowPrivilegeEscalation, unrestricted capabilities, privileged, runAsNonRoot/runAsUser=0, hostPath volumes, seccompProfile.
- `kubectl get deploy logger -n psa-fast` shows `2/2` ready.
- `kubectl exec -n psa-fast deploy/logger -- tail -n 2 /host-logs/out.log` prints timestamps.
- `kubectl get pod -n psa-fast -o yaml | grep -E 'privileged|hostPath'` returns nothing.

## Answer
[answers/week-04-microservice-vulnerabilities/day-02-psa-troubleshoot-fast.md](../../answers/week-04-microservice-vulnerabilities/day-02-psa-troubleshoot-fast.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete namespace `psa-fast`.
