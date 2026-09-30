# Week 1 · Day 3 (Sep 25) — CIS benchmark with kube-bench
**Domain:** Cluster Setup (15%) — CIS benchmark of Kubernetes components | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Run kube-bench against the control-plane node of the kind cluster and read the report.
- Map a `[FAIL]` line to the exact file/flag it audits.
- Remediate at least three findings by editing files/static pod manifests on the node.
- Re-run and confirm the findings now pass without breaking the cluster.

## Theory
- kube-bench implements the CIS Kubernetes Benchmark. It checks: master/control-plane node config (section 1: file permissions/ownership on manifests and PKI, and API server, controller-manager, scheduler flags), etcd (section 2), control-plane configuration such as authn/audit (section 3), worker node config (section 4: kubelet flags/config, file perms) and policies (section 5: RBAC, PSA, NetworkPolicy, secrets).
- Results: `[PASS]`, `[FAIL]`, `[WARN]` (manual check or not automatable), `[INFO]`. Each FAIL is followed in the "Remediations" block by the recommended fix text.
- Typical items: manifest files mode 600 or stricter and owner root:root; `--anonymous-auth=false`; `--profiling=false` on apiserver/controller-manager/scheduler; `--authorization-mode` not `AlwaysAllow` and includes `Node,RBAC`; `--client-cert-auth=true` and no `--auto-tls` on etcd; kubelet `authentication.anonymous.enabled=false`, `authorization.mode=Webhook`, `readOnlyPort=0`.
- Control-plane components run as static pods from `/etc/kubernetes/manifests/`. The kubelet watches that directory; saving an edited manifest makes the kubelet recreate the pod. A malformed manifest means the component silently stops coming back.
- kube-bench job manifests (from aquasecurity/kube-bench): `job-master.yaml` (control-plane checks), `job-node.yaml` (worker checks), `job.yaml` (generic). They mount host paths (`/etc/kubernetes`, `/var/lib/etcd`, `/var/lib/kubelet`, `/usr/bin`) and use `hostPID`.
- Exam pattern: read the finding, locate the file, change the flag/permission, wait for the component to restart, verify. Keep a backup of manifests outside `/etc/kubernetes/manifests/` (files in that directory ending in any extension may be treated as manifests).
- Useful commands: `kubectl logs job/<name>`, `crictl ps` on the node, `kubectl get pods -n kube-system`, `stat -c '%a %U:%G' <file>`, `docker exec -it cks-control-plane bash`.

## Prerequisites
Internet access from the cluster and your machine (job manifest and image pull). A shell on the control-plane node: `docker exec -it cks-control-plane bash`.

## Exam-style question
Context: cluster `kind-cks` has control-plane node `cks-control-plane`, and a kube-bench scan of it reports `[FAIL]` findings. Task: run kube-bench against the control-plane node with the `job-master.yaml` job, save the log to `~/kube-bench-before.txt`, and fix three failing checks: one file-permission finding on the static pod manifests, one kube-apiserver flag finding, and one kube-scheduler or kube-controller-manager flag finding. Requirements: re-run the scan and save the log to `~/kube-bench-after.txt` showing the three fixed checks as `[PASS]`. Do not break the cluster: all control-plane pods in `kube-system` must be Running and `kubectl get nodes` must work, and leave no backup files in `/etc/kubernetes/manifests/`.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Apply the kube-bench control-plane job (`job-master.yaml` from the `aquasecurity/kube-bench` repo, `main` branch) to the `default` namespace. Ensure the pod is scheduled on the control-plane node, wait for the job to complete, and save its log to `~/kube-bench-before.txt`.
2. From the log, list the `[FAIL]` results in sections 1.1 (file permissions), 1.2 (API server) and 1.3/1.4 (controller-manager/scheduler). If the job errors on benchmark auto-detection for this Kubernetes version, pass an appropriate `--benchmark` argument in the job spec.
3. Select and remediate three FAILs, one of each kind:
   a. a file permission finding on the static pod manifests under `/etc/kubernetes/manifests/`;
   b. a kube-apiserver flag finding that you can fix without disrupting cluster access (do NOT choose a fix that makes the API server unhealthy);
   c. a kube-scheduler or kube-controller-manager flag finding.
4. After editing manifests, wait until all control-plane pods in `kube-system` are Running again and `kubectl get nodes` works.
5. Delete the job, re-apply it, save the new log to `~/kube-bench-after.txt`, and confirm the three checks you fixed now show `[PASS]`.
6. Write down (one line each) what the remaining `--anonymous-auth` (1.2.1) finding, if present, would require, and the risk of applying it on a kubeadm-based control plane.

## Check your work
- `~/kube-bench-before.txt` contains `== Summary master ==` with a non-zero FAIL count.
- The three chosen check IDs are `[FAIL]` in the before log and `[PASS]` in the after log (`grep -E '^\[(PASS|FAIL)\] 1\.(1\.1|2\.[0-9]+|3\.[0-9]+|4\.[0-9]+)' ...`).
- `kubectl get pods -n kube-system` shows kube-apiserver, kube-controller-manager, kube-scheduler and etcd Running; `kubectl get --raw /readyz` returns `ok`.
- The edited manifests are valid YAML and no backup files remain in `/etc/kubernetes/manifests/`.

## Answer
[answers/week-01-cluster-setup/day-03-cis-kube-bench.md](../../answers/week-01-cluster-setup/day-03-cis-kube-bench.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete the kube-bench job (`kubectl delete job -l app=kube-bench` or by name). Keep the manifest fixes; they do not interfere with later days.
