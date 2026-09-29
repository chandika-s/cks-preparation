# Week 6 · Day 5 (Nov 1) — Ensure immutability of containers at runtime — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-05-container-runtime-immutability.md](../../plan/week-06-monitoring-logging-runtime-security/day-05-container-runtime-immutability.md)

## Solution
1. Create:
```
kubectl create ns immutable
kubectl create deploy web -n immutable --image=nginxinc/nginx-unprivileged:1.27-alpine --port=8080
kubectl rollout status deploy/web -n immutable
```
2. Read-only root FS:
```
kubectl edit deploy web -n immutable
```
Add under the container:
```yaml
        securityContext:
          readOnlyRootFilesystem: true
```
Observe:
```
kubectl get pods -n immutable
kubectl logs -n immutable <new-pod>
```
Log shows nginx failing to open `/tmp/nginx.pid` (`Read-only file system`).
3-5. Final Deployment spec (`kubectl apply -f` or edit):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: immutable
spec:
  replicas: 1
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```
No capabilities are needed: the image runs as non-root user 101 on port 8080.
6. Verify:
```
POD=$(kubectl get pod -n immutable -l app=web -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n immutable $POD -- touch /newfile
kubectl exec -n immutable $POD -- touch /tmp/ok
kubectl exec -n immutable $POD -- grep Cap /proc/1/status
```
7. `kubectl exec -n immutable $POD -- wget -qO- localhost:8080 | head -3`

## Expected output
```
touch: /newfile: Read-only file system
command terminated with exit code 1
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000000000000000
```
`touch /tmp/ok` exits 0. Deployment `1/1`.

## Why it works
The runtime mounts the container rootfs read-only; the `emptyDir` is a separate writable mount only at `/tmp`, so the write surface is one path. `no_new_privs` and an empty capability set stop privilege gain. With `runAsNonRoot` and the unprivileged image, no capability is needed.

## Common mistakes / exam gotchas
- `readOnlyRootFilesystem` placed at pod level: invalid (container-only field); the API rejects the unknown field on strict validation.
- Mounting `emptyDir` over `/` or wide paths defeats the purpose.
- With the stock `nginx` image (root, port 80, writes `/var/cache/nginx`, `/var/run`), you need writable mounts for those two paths and, with `drop: ["ALL"]`, add back `CHOWN`, `SETGID`, `SETUID` (and possibly `NET_BIND_SERVICE`). Add caps one at a time from the error messages.
- `capabilities.add` without `drop: ["ALL"]` just widens the default set.
- `runAsNonRoot: true` with an image whose user is a name (non-numeric) can fail verification; set `runAsUser`.
- Editing the running Pod: most securityContext fields are immutable; edit the Deployment.
- kind/macOS: nothing platform-specific; seccomp `RuntimeDefault` is supported by containerd.

## Cleanup
```
kubectl delete ns immutable
```
