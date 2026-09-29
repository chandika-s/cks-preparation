# Week 5 · Day 7 (Oct 26) — Static analysis: Kubesec and KubeLinter — Answers
Task: [day-07-kubesec-kubelinter.md](../../plan/week-05-supply-chain-security/day-07-kubesec-kubelinter.md)

## Solution
1. Create `deployment.yaml` exactly as in the task.
2. Kubesec:
```
cd workspace/week-05/day-07
kubesec scan deployment.yaml
kubesec scan deployment.yaml | jq '.[0] | {score, critical: [.scoring.critical[]?.selector], advise: [.scoring.advise[]?.selector]}'
```
Without a local binary: `docker run -i kubesec/kubesec:v2 scan /dev/stdin < deployment.yaml`.
Expected critical selectors: `containers[] .securityContext .privileged == true`, `.spec.hostNetwork`, and `containers[] .volumeMounts[] .mountPath == /var/run/docker.sock` (or hostPath docker.sock). Advise items: `containers[] .securityContext .runAsNonRoot == true`, `.readOnlyRootFilesystem == true`, `.capabilities .drop | index("ALL")`, `resources.limits.cpu/memory`, `resources.requests.*`, `.serviceAccountName`, seccomp.

3. KubeLinter:
```
kube-linter lint deployment.yaml
echo $?
```
Typical failures: `privileged-container`, `host-network`, `docker-sock`, `latest-tag`, `run-as-non-root`, `no-read-only-root-fs`, `privilege-escalation-container`, `unset-cpu-requirements`, `unset-memory-requirements`, `no-liveness-probe`, `no-readiness-probe`, `default-service-account`, `minimum-three-replicas`, `no-anti-affinity`, `drop-net-raw-capability`. KubeLinter has no numeric score; Kubesec flags seccomp/AppArmor and UID > 10000, while KubeLinter flags `latest-tag`, probes, replica count and anti-affinity that Kubesec ignores.

4. `deployment-fixed.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-sa
  namespace: default
automountServiceAccountToken: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: default
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      serviceAccountName: web-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: web
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          privileged: false
          capabilities:
            drop: ["ALL"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        readinessProbe:
          httpGet:
            path: /
            port: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
```
5. Verify and apply:
```
kube-linter lint deployment-fixed.yaml; echo $?
kubesec scan deployment-fixed.yaml | jq '.[] | {object, score, critical: .scoring.critical}'
kubectl apply -f deployment-fixed.yaml
kubectl rollout status deploy/web
kubectl exec deploy/web -- id
```
Kubesec scans one object per list entry; the ServiceAccount entry reports "not a supported kind" style output, which is expected. If a KubeLinter check still fails, read its message, and only if it is unjustified add an exclusion via `--exclude <check>` or a config file.

## Expected output
Before: Kubesec `"score": -30` or lower (negative) with three critical items; KubeLinter prints `Error: found N lint errors` (exit 1).
After: KubeLinter prints `No lint errors found!` (exit 0); Kubesec Deployment `score` roughly 8-12 with `critical` empty; `kubectl exec deploy/web -- id` prints `uid=10001 gid=10001`.

## Why it works
Both tools evaluate the static PodSpec: each hardening field removes a critical finding or earns points (Kubesec) or satisfies a check (KubeLinter). `readOnlyRootFilesystem` breaks apps that write to disk, so writable paths get `emptyDir` mounts. Preferred anti-affinity spreads replicas without leaving pods `Pending` on a small kind cluster, while still satisfying `no-anti-affinity`.

## Common mistakes / exam gotchas
- Using the official `nginx` image with `runAsNonRoot`: it binds port 80 and writes `/var/run`, so it fails (`CreateContainerConfigError` or permission denied); use an unprivileged variant or `runAsUser`+port>1024.
- `runAsNonRoot: true` with an image that has a non-numeric `USER` and no `runAsUser` fails: kubelet cannot verify. Give a numeric UID.
- Required (not preferred) anti-affinity with 3 replicas leaves pods Pending when there are fewer than 3 schedulable nodes (the kind control-plane is tainted).
- Read-only root plus no writable mounts crashes nginx and many apps.
- Kubesec advice is not policy: a high score does not equal compliance. KubeLinter check names/defaults differ by version.
- On the exam the fix is often "edit the given manifest until the tool passes or the specific finding disappears"; fix exactly what is asked.
- Kubesec's `advise` for AppArmor/seccomp annotations may not apply the same way on kind (AppArmor is unavailable on kind/macOS nodes); seccomp `RuntimeDefault` does work.

## Cleanup
```
kubectl delete deploy web
kubectl delete sa web-sa
```
