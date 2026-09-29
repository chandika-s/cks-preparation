# Week 7 · Day 2 (Nov 6) — Mixed set: CIS remediation + Pod Security Standards + Trivy — Answers
Task: [plan/week-07-mock-exams/day-02-cis-pss-trivy.md](../../plan/week-07-mock-exams/day-02-cis-pss-trivy.md)

## Solution

### Task 1 — CIS remediation
Get findings first (whichever way you set it up in Week 1):
```
docker exec cks-control-plane kube-bench run --targets master 2>&1 | grep -E 'FAIL|profiling|1\.1\.'
```
If kube-bench is run as a Job: `kubectl logs job/kube-bench`.

Controller manager and scheduler:
```
docker exec -it cks-control-plane bash
vi /etc/kubernetes/manifests/kube-controller-manager.yaml
vi /etc/kubernetes/manifests/kube-scheduler.yaml
```
In each, under `spec.containers[0].command`, add `- --profiling=false`. The kubelet recreates each static pod within seconds.

Permissions:
```
chmod 600 /etc/kubernetes/manifests/kube-scheduler.yaml
chown root:root /etc/kubernetes/manifests/kube-scheduler.yaml
stat -c '%a %U:%G' /etc/kubernetes/manifests/kube-scheduler.yaml
```
Kubelet (repeat on `cks-worker`):
```
grep -A3 -E 'anonymous|authorization|readOnlyPort' /var/lib/kubelet/config.yaml
```
Required state in `/var/lib/kubelet/config.yaml`:
```yaml
authentication:
  anonymous:
    enabled: false
authorization:
  mode: Webhook
readOnlyPort: 0
```
Add `readOnlyPort: 0` at top level if missing. Then:
```
systemctl restart kubelet
systemctl is-active kubelet
```
Re-run kube-bench, confirm PASS, then `kubectl get nodes; kubectl -n kube-system get pods`.

kind note: kube-bench's autodetected kubernetes version/targets may not map perfectly to kubeadm-in-container; some checks report WARN/FAIL regardless (for example paths under `/var/lib/etcd` or unit-file checks for kubelet where the systemd unit path differs). Fix what you can and be able to explain the rest.

### Task 2 — PSA restricted
```
kubectl create ns payments
kubectl label ns payments \
  pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/warn-version=latest
kubectl apply -f broken.yaml
kubectl -n payments get rs
kubectl -n payments describe rs -l app=ledger-api | grep -i -A3 forbidden
```
Fixed Deployment (delete the old one or `kubectl apply` over it; `hostNetwork` removal is a normal field change):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-api
  namespace: payments
spec:
  replicas: 2
  selector:
    matchLabels: {app: ledger-api}
  template:
    metadata:
      labels: {app: ledger-api}
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: nginxinc/nginx-unprivileged:1.27
        ports:
        - containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```
`batch-job`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: batch-job
  namespace: payments
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: job
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```
Verify: `kubectl -n payments exec batch-job -- id`.

### Task 3 — Trivy
```
kubectl -n scan get pods -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
: > /tmp/trivy-report.txt
for img in nginx:1.16 alpine:3.12 busybox:1.36; do
  c=$(trivy image -q -f json --severity CRITICAL $img | jq '[.Results[]?.Vulnerabilities[]?] | length')
  h=$(trivy image -q -f json --severity HIGH $img | jq '[.Results[]?.Vulnerabilities[]?] | length')
  echo "$img CRITICAL=$c HIGH=$h" >> /tmp/trivy-report.txt
done
cat /tmp/trivy-report.txt
```
Delete deployments whose line has `CRITICAL=` greater than 0 (expected: `nginx:1.16` and `alpine:3.12`; `busybox:1.36` is usually 0 or low but check your output):
```
kubectl -n scan delete deploy old-nginx old-alpine
```
Replace and verify:
```
trivy image --severity CRITICAL nginx:1.27-alpine
kubectl -n scan create deploy old-nginx --image=nginx:1.27-alpine
kubectl -n scan rollout status deploy old-nginx
trivy image --severity HIGH,CRITICAL nginx:1.27-alpine > /tmp/trivy-final.txt
```
Vulnerability data changes daily, so exact counts differ; if `1.27-alpine` shows CRITICAL, pick a newer patch tag and rescan. Use `--ignore-unfixed` if the question says to only consider fixable issues.

### Task 4 — PSA baseline with warnings
```
kubectl create ns legacy
kubectl label ns legacy pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
kubectl -n legacy run probe --image=nginx:1.27 --dry-run=server 2> /tmp/psa-warnings.txt
cat /tmp/psa-warnings.txt
kubectl -n legacy apply -f - 2> /tmp/psa-reject.txt <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: spy
spec:
  hostPID: true
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep","3600"]
EOF
cat /tmp/psa-reject.txt
```
Warnings go to stderr, hence `2>`.

### Task 5 — Dockerfile
```
mkdir -p /tmp/mock2 && cd /tmp/mock2
cat > Dockerfile <<'EOF'
FROM python:3.12-slim
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY app.py .
USER 10001
CMD ["python3", "app.py"]
EOF
```
Stronger: pin by digest (`python:3.12-slim@sha256:...`) and multi-stage if compiling.

## Expected output
- Task 1: kube-bench lines `[PASS] 1.3.2`, `[PASS] 1.4.1`, perms check PASS; stat prints `600 root:root`.
- Task 2: `deployment.apps/ledger-api ... 2/2`; before the fix the RS event says `violates PodSecurity "restricted:latest": host namespaces (hostNetwork=true), privileged (container "api" must not set securityContext.privileged=true), allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile ...`.
- Task 3: report resembles `nginx:1.16 CRITICAL=<large> HIGH=<large>`.
- Task 4: `Warning: would violate PodSecurity "restricted:latest": ...`; `Error from server (Forbidden): ... violates PodSecurity "baseline:latest": host namespaces (hostPID=true)`.

## Why it works
- Static pod manifests are watched by the kubelet; saving a valid change restarts the pod with the new flag.
- PSA `restricted` is a closed checklist; each rejection message lists exactly the fields to change.
- Trivy compares package versions in image layers to advisories; a newer/smaller base has fewer vulnerable packages.

## Common mistakes / exam gotchas
- Typo in a manifest under `/etc/kubernetes/manifests` takes the control plane down; edit carefully and watch `crictl ps -a`.
- Leaving `.bak` files in the manifests directory.
- `runAsNonRoot: true` with an image that runs as root (nginx:1.27) fails with `container has runAsNonRoot and image will run as root`; use an unprivileged image or set `runAsUser`.
- Missing `seccompProfile` at pod or container level.
- Editing kubelet config but forgetting `systemctl restart kubelet`, or only doing the control plane node.
- Forgetting `--dry-run=server` (client dry run does not run admission).
- Trivy: forgetting `--severity` or reading only the top-of-table summary.

## Cleanup
```
kubectl delete ns payments scan legacy
rm -rf /tmp/mock2
```
