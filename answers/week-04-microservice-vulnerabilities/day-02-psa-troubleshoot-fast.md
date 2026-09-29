# Week 4 · Day 2 (Oct 13) — Troubleshooting PSA + writing compliant specs fast — Answers
Task: [day-02-psa-troubleshoot-fast](../../plan/week-04-microservice-vulnerabilities/day-02-psa-troubleshoot-fast.md)

## Solution
1. Namespace:
```
kubectl create ns psa-fast
kubectl label ns psa-fast pod-security.kubernetes.io/enforce=restricted
mkdir -p ~/psa-fast
```
2. Save the broken manifest to `~/psa-fast/broken.yaml` and `kubectl apply -f ~/psa-fast/broken.yaml`. The Deployment is created (with a `Warning: would violate PodSecurity` only if a `warn` label is set).
3. Find the reason:
```
kubectl get deploy,rs,pods -n psa-fast
kubectl describe rs -n psa-fast
kubectl get events -n psa-fast --sort-by=.lastTimestamp
```
4. `~/psa-fast/fixed.yaml`:
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
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: logger
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /host-logs/out.log; sleep 5; done"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: logs
          mountPath: /host-logs
      volumes:
      - name: logs
        emptyDir: {}
```
```
kubectl apply -f ~/psa-fast/fixed.yaml
kubectl rollout status deploy/logger -n psa-fast
```
5. `emptyDir` is writable by the pod; with `runAsUser: 1000` and no `fsGroup`, emptyDir is mode 0777 so writes succeed.

## Expected output
Event from step 3 (abbreviated):
```
Error creating: pods "logger-xxxx-" is forbidden: violates PodSecurity "restricted:latest": privileged (container "logger" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (...), unrestricted capabilities (...), restricted volume types (volume "logs" uses restricted volume type "hostPath"), runAsNonRoot != true (...), seccompProfile (...)
```
After the fix: `deployment "logger" successfully rolled out`, `2/2` ready.

## Why it works
The message lists all violations together, so one edit pass suffices. The four seeded faults map to: `runAsUser: 0` → non-root; `privileged: true` → removed; `hostPath` → `emptyDir`; no seccomp → `RuntimeDefault`. The two additional restricted requirements (`allowPrivilegeEscalation: false`, drop ALL) were implicit and easy to miss.

## Common mistakes / exam gotchas
- Fixing only the four "obvious" faults and forgetting `allowPrivilegeEscalation`/`capabilities`, causing another round trip.
- Editing the Pod instead of the Deployment template (pods are immutable in these fields).
- Putting `allowPrivilegeEscalation`/`capabilities` at pod-level `securityContext` (invalid; container-level only).
- `runAsNonRoot: true` without `runAsUser` for an image whose default user is root: pod stays `CreateContainerConfigError`.
- Reading `kubectl get pods` (empty) instead of ReplicaSet events.
- Scaffold quickly: `k create deploy x --image=busybox:1.36 $do > d.yaml`, then add the securityContext block from cheatsheet.md.

## Cleanup
```
kubectl delete ns psa-fast
rm -rf ~/psa-fast
```
