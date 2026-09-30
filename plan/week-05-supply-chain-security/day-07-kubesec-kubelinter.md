# Week 5 · Day 7 (Oct 26) — Static analysis: Kubesec and KubeLinter
**Domain:** Supply Chain Security (20%) — Static analysis of workloads | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Scan a manifest with Kubesec and KubeLinter and interpret score and findings.
- Compare what each tool flags.
- Harden the manifest until both tools report clean/high-scoring results, and apply it to the cluster.

## Theory
These tools lint Kubernetes manifests for security misconfigurations (missing `securityContext`, running as root, no resource limits, `hostNetwork: true`, etc.) before you ever apply them; they run in CI on YAML, not on a live cluster.

- **Kubesec** (`kubesec scan file.yaml`; container: `docker run -i kubesec/kubesec:v2 scan /dev/stdin < file.yaml`; also `kubesec http`). Output is JSON per object: `score`, `scoring.critical[]` (score reduces, e.g. `privileged: true`, `hostPID`, `hostNetwork`, docker.sock mounts, `SYS_ADMIN`), `scoring.passed[]` (adds points), `scoring.advise[]` (suggested improvements). Score can be negative; the rule of thumb is a positive, high score with no critical items. Points come from items such as `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `runAsUser` > 10000, `capabilities.drop: ["ALL"]`, `resources.limits/requests` (cpu, memory), `serviceAccountName`, seccomp, AppArmor annotations.
- **KubeLinter** (`kube-linter lint file.yaml|dir`): rule-based, YAML/Helm. Exit code non-zero when any check fails. Useful: `kube-linter checks list`, `--config .kube-linter.yaml`, `--do-not-auto-add-defaults`, `--include`/`--exclude`. Default checks include `run-as-non-root`, `no-read-only-root-fs`, `privileged-container`, `privilege-escalation-container`, `host-network`, `host-pid`, `host-ipc`, `unset-cpu-requirements`, `unset-memory-requirements`, `latest-tag`, `no-liveness-probe`, `no-readiness-probe`, `drop-net-raw-capability`, `env-var-secret`, `default-service-account`, `minimum-three-replicas`, `no-anti-affinity`, `sensitive-host-mounts`, `docker-sock`, `dangling-service`. Exact defaults vary by version; trust `kube-linter checks list`.
- Kubesec and KubeLinter overlap but do not agree: Kubesec scores, KubeLinter pass/fails against a policy. Neither replaces admission control (PSA/Kyverno) or runtime detection.
- Fix vocabulary: `securityContext` at pod level (`runAsNonRoot`, `runAsUser`, `seccompProfile`) and container level (`allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, `privileged: false`).

## Prerequisites
`kubesec` (binary or docker image) and `kube-linter` installed on the host. Cluster access for step 5.

## Exam-style question
Context: `workspace/week-05/day-07/deployment.yaml` defines Deployment `insecure-web` in `default` that uses host networking, a privileged container and a mounted docker.sock. Task: scan it with Kubesec and KubeLinter, record the findings in `workspace/week-05/day-07/findings.txt`, and produce a hardened replacement `deployment-fixed.yaml` for a Deployment named `web` (3 replicas, image `nginxinc/nginx-unprivileged:1.27`, ServiceAccount `web-sa`). Requirements: `kube-linter lint` must exit 0, Kubesec must report no `critical` items, and the fixed manifest must be applied so all pods are Running.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create `workspace/week-05/day-07/deployment.yaml` containing this deliberately insecure Deployment:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: insecure-web
     namespace: default
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: insecure-web
     template:
       metadata:
         labels:
           app: insecure-web
       spec:
         hostNetwork: true
         containers:
         - name: web
           image: nginx:latest
           securityContext:
             privileged: true
           volumeMounts:
           - name: sock
             mountPath: /var/run/docker.sock
         volumes:
         - name: sock
           hostPath:
             path: /var/run/docker.sock
   ```
2. Run `kubesec scan deployment.yaml`. Record the score and list every `critical` item and at least three `advise` items in `findings.txt`.
3. Run `kube-linter lint deployment.yaml`. Record the check names that fail. List at least two findings reported by one tool but not the other.
4. Write `deployment-fixed.yaml` that fixes the manifest. Requirements: Deployment named `web` (labels `app: web`); no `hostNetwork`, no privileged container, no docker.sock mount or host path; image `nginxinc/nginx-unprivileged:1.27` (pinned, non-root capable, listens on 8080); run as non-root (numeric UID > 10000); read-only root filesystem (mount `emptyDir` volumes as needed for `/tmp`, `/var/cache/nginx`, `/var/run` since that image writes there); no privilege escalation; drop all capabilities; RuntimeDefault seccomp; CPU and memory requests and limits; readiness and liveness probes; a dedicated ServiceAccount `web-sa` with `automountServiceAccountToken: false`; 3 replicas with pod anti-affinity by hostname; explicit namespace `default`.
5. Iterate until `kube-linter lint deployment-fixed.yaml` exits 0 and Kubesec gives a positive score with an empty `critical` list. Then apply the fixed manifest (and the ServiceAccount) to the cluster and confirm the pods run.

## Check your work
- `kubesec scan deployment.yaml` returns a negative or very low score with `critical` entries (privileged, hostNetwork, docker.sock).
- `kube-linter lint deployment.yaml` exits non-zero with multiple failing checks.
- For the fixed file: `kube-linter lint deployment-fixed.yaml; echo $?` prints `0` (or only your documented, justified exclusions); Kubesec `.[0].scoring.critical` is absent or empty and score is markedly higher than before.
- `kubectl get deploy web -n default` shows `3/3` ready; pods show `readOnlyRootFilesystem` and non-root effective user (`kubectl exec <pod> -- id`).

## Answer
[answers/week-05-supply-chain-security/day-07-kubesec-kubelinter.md](../../answers/week-05-supply-chain-security/day-07-kubesec-kubelinter.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete deploy web
kubectl delete sa web-sa
```
