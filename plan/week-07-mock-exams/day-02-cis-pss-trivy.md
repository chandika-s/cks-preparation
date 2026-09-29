# Week 7 · Day 2 (Nov 6) — Mixed set: CIS remediation + Pod Security Standards + Trivy
**Domain:** Cluster Setup (15%) + Minimize Microservice Vulnerabilities (20%) + Supply Chain Security (20%) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Remediate kube-bench findings by editing static pod manifests, file permissions and kubelet config, then re-verify.
- Write and repair specs that satisfy Pod Security Admission `restricted`.
- Scan images with Trivy, act on results, and harden a Dockerfile.

## Theory
**CIS / kube-bench.** kube-bench maps CIS Kubernetes Benchmark checks to sections: 1.x control plane (1.1 file perms/ownership, 1.2 apiserver flags, 1.3 controller-manager, 1.4 scheduler), 2.x etcd, 3.x control plane config, 4.x worker (4.1 kubelet files, 4.2 kubelet config), 5.x policies. Output has `[FAIL]`, `[WARN]`, `[PASS]` and a Remediations block. Typical fixes: add/modify a flag in `/etc/kubernetes/manifests/*.yaml` (kubelet restarts the static pod automatically), `chmod 600`/`chown root:root` on manifests and kubeconfigs, edit `/var/lib/kubelet/config.yaml` then `systemctl restart kubelet`. Match findings by description, not just number, since numbering differs across benchmark versions. Never leave backups inside `/etc/kubernetes/manifests`.

**Pod Security Admission.** Namespace labels `pod-security.kubernetes.io/<mode>=<level>` with modes `enforce`, `audit`, `warn` and levels `privileged`, `baseline`, `restricted`; optional `<mode>-version`. `restricted` requires: `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` (only `NET_BIND_SERVICE` may be added), `runAsNonRoot: true`, `seccompProfile.type` of `RuntimeDefault` or `Localhost`, no privileged, no hostNamespaces/hostPath/hostPorts, limited volume types, non-root user. Controllers (Deployment) create objects fine and the ReplicaSet reports the rejection in events; bare Pods are rejected at create. Tip: `kubectl apply --dry-run=server` or `warn` mode surfaces violations.

**Trivy.** `trivy image [--severity HIGH,CRITICAL] [--ignore-unfixed] [--exit-code 1] [-f json|table] <image>`; also `trivy image --input file.tar`, `trivy config <dir>`, `trivy fs`. Fixing means bumping to a patched tag or a smaller base (alpine/distroless/slim), then rescanning. Image references must be exact tags or digests.

**Dockerfile hygiene.** Pin base tag (or digest), minimal base, `COPY` not `ADD`, no unneeded packages or tools, multi-stage builds, run as numeric non-root `USER`, one process, no secrets in layers.

## Prerequisites
- Cluster `kind-cks`; kube-bench available as configured in Week 1 Day 3 (binary in the node, or Job manifest); Trivy installed on the host and able to reach its vulnerability DB (internet).
- Nodes `cks-control-plane` and `cks-worker` reachable via `docker exec`.

## Task
Total 90 min / 100 points. Work in the order given or rotate; time each task.

### Task 1 — CIS remediation (20 min, 25 pts)
Run kube-bench for master and node targets (`--targets master,node` or your Week 1 Job). Remediate these findings, identified by description:
1. Controller manager: "Ensure that the `--profiling` argument is set to false".
2. Scheduler: "Ensure that the `--profiling` argument is set to false".
3. "Ensure that the scheduler pod specification file permissions are set to 600 or more restrictive" (`/etc/kubernetes/manifests/kube-scheduler.yaml`), owner `root:root`.
4. On both nodes, kubelet: anonymous auth disabled, authorization mode not `AlwaysAllow` (`Webhook`), and the read-only port disabled (`readOnlyPort: 0`) explicitly in `/var/lib/kubelet/config.yaml`.
5. Re-run kube-bench and record that the above checks now report PASS. All control plane pods and both nodes must remain Ready.

### Task 2 — Pod Security `restricted` (15 min, 20 pts)
1. Create namespace `payments` with `enforce=restricted`, and `audit=restricted`, `warn=restricted`, each pinned to `latest`.
2. Create Deployment `ledger-api` in `payments` from the file below, which currently ends up with 0/2 pods. Fix the manifest (you may change the image to `nginxinc/nginx-unprivileged:1.27`, container port becomes 8080) so both replicas run without changing the namespace labels:
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
      hostNetwork: true
      containers:
      - name: api
        image: nginx:1.27
        ports:
        - containerPort: 80
        securityContext:
          privileged: true
```
3. Create Pod `batch-job` in `payments` (image `busybox:1.36`, command `sleep 3600`) that is admitted under `restricted`, running as UID/GID 10001.

### Task 3 — Trivy scan and fix (20 min, 25 pts)
Setup: `kubectl create ns scan; kubectl -n scan create deploy old-nginx --image=nginx:1.16; kubectl -n scan create deploy old-alpine --image=alpine:3.12 -- sleep 3600; kubectl -n scan create deploy tiny --image=busybox:1.36 -- sleep 3600`.
1. Using Trivy, scan every image used by pods in namespace `scan` for HIGH and CRITICAL vulnerabilities. Write one line per image to `/tmp/trivy-report.txt`: `<image> CRITICAL=<n> HIGH=<n>`.
2. Delete every Deployment in `scan` whose image has at least one CRITICAL vulnerability.
3. Re-create `old-nginx` with a version of `nginx` that has zero CRITICAL vulnerabilities (verify with Trivy, prefer an `-alpine` or newer tag) and verify it runs.
4. Save the full table for that final image to `/tmp/trivy-final.txt`.

### Task 4 — PSA baseline with warnings (10 min, 15 pts)
1. Create namespace `legacy` with `enforce=baseline`, `warn=restricted`, `audit=restricted`.
2. Using a server-side dry run, show which warnings a plain `nginx:1.27` pod (name `probe`) would trigger, and save the warning text to `/tmp/psa-warnings.txt`.
3. Show that a pod with `hostPID: true` named `spy` is rejected in `legacy`. Save the error to `/tmp/psa-reject.txt`.

### Task 5 — Dockerfile hardening (10 min, 15 pts)
Create `/tmp/mock2/Dockerfile` with the content below, then rewrite it (in place) to meet: pinned minimal Python base (`python:3.12-slim`), no extra tools installed, `COPY` instead of `ADD`, numeric non-root user `10001`, working dir `/app`.
```
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl vim git python3
ADD app.py /app/app.py
CMD ["python3","/app/app.py"]
```

## Check your work
- Task 1: kube-bench shows PASS for the five items; `stat -c '%a %U:%G' /etc/kubernetes/manifests/kube-scheduler.yaml` prints `600 root:root`; `ps`/manifest of controller-manager and scheduler include `--profiling=false`; `kubectl get nodes` Ready.
- Task 2: `kubectl -n payments get deploy ledger-api` 2/2; no `hostNetwork`/`privileged` in the live spec; `batch-job` Running and `id` inside shows uid 10001; a privileged test pod in `payments` is rejected.
- Task 3: report file has three lines; deleted deployments are exactly those with CRITICAL>0; final image scan shows CRITICAL 0.
- Task 4: dry-run output contains "would violate PodSecurity "restricted:latest"" warnings; `spy` is `Forbidden` under `baseline:latest`.
- Task 5: Dockerfile has `FROM python:3.12-slim`, `COPY`, `USER 10001`, no `apt-get install`.

## Answer
[answers/week-07-mock-exams/day-02-cis-pss-trivy.md](../../answers/week-07-mock-exams/day-02-cis-pss-trivy.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns payments scan legacy
rm -rf /tmp/mock2
```
Control plane changes from Task 1 are safe to keep.
