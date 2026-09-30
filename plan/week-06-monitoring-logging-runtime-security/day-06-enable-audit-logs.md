# Week 6 · Day 6 (Nov 2) — Enable and configure Kubernetes audit logs
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Write an audit policy with per-resource levels.
- Wire the policy and log path into the kube-apiserver static pod (including volume mounts).
- Find a specific event in the resulting log.

## Theory
Audit logging records requests to the API server in stages: `RequestReceived`, `ResponseStarted` (long-running requests), `ResponseComplete`, `Panic`. Configuration is via kube-apiserver flags:

- `--audit-policy-file=<path>`: policy file (`apiVersion: audit.k8s.io/v1`, `kind: Policy`).
- `--audit-log-path=<path>`: write JSON lines to this file (`-` = stdout).
- Rotation: `--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize` (MB).
- Levels per rule: `None` (drop), `Metadata` (user, verb, resource, no bodies), `Request` (adds request body), `RequestResponse` (adds response body; not for non-resource requests).
- Rules are evaluated in order; the first match wins. Put specific rules first and a catch-all last. Match on `users`, `userGroups`, `verbs`, `resources` (`group` + `resources`, optional `resourceNames`), `namespaces`, `nonResourceURLs`. `omitStages: ["RequestReceived"]` reduces volume.
- The apiserver is a static pod (`/etc/kubernetes/manifests/kube-apiserver.yaml`), so the policy and log directory must be `hostPath` volumes mounted into the container. The kubelet restarts the pod when the manifest changes; the API is unavailable for roughly a minute. A broken manifest keeps it down: inspect with `crictl ps -a` and `crictl logs` on the node.
- Do not leave backup copies of manifests inside `/etc/kubernetes/manifests/`; the kubelet runs every file there.
- On kind the "node" is a Docker container: `docker exec -it cks-control-plane bash`. Files under `/etc/kubernetes` and `/var/log` live inside that container. (Alternative: `extraMounts` and `kubeadmConfigPatches` at cluster creation; here we edit the running node.)
- Logging Secrets at `RequestResponse` writes secret contents in cleartext to the audit log. Real policies use `Metadata` for secrets; the exercise uses `RequestResponse` to match the exam pattern.

## Prerequisites
Cluster `kind-cks` up. A secret to read (created below). Note: Day 7 needs the audit log configured here.

## Exam-style question
Context: the kube-apiserver on node `cks-control-plane` has no audit logging, and Secret `db-creds` is used in namespace `default`. Task: enable audit logging with the policy file `/etc/kubernetes/audit/policy.yaml` and log file `/var/log/kubernetes/audit/audit.log`, retaining 7 days, 3 backups and 100 MB per file. Requirements: omit the `RequestReceived` stage, log `secrets` at `RequestResponse` and everything else at `Metadata`; back up the apiserver manifest outside `/etc/kubernetes/manifests/` first; the cluster must be healthy again afterwards; show that a `get` of `db-creds` is logged at `RequestResponse` with a `responseObject`, while a `get pods` event is `Metadata` only.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Open a shell on the control-plane node (`cks-control-plane`).
2. Create a Secret `db-creds` in namespace `default` with key `password` (any value).
3. On the node, create directory `/etc/kubernetes/audit` and write `/etc/kubernetes/audit/policy.yaml`, an audit policy that:
   - omits the `RequestReceived` stage,
   - logs access to `secrets` (core group) at `RequestResponse`,
   - logs everything else at `Metadata`.
4. Back up `/etc/kubernetes/manifests/kube-apiserver.yaml` to a location outside `/etc/kubernetes/manifests/`.
5. Edit the kube-apiserver static pod manifest:
   - `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`
   - `--audit-log-path=/var/log/kubernetes/audit/audit.log`
   - `--audit-log-maxage=7`, `--audit-log-maxbackup=3`, `--audit-log-maxsize=100`
   - hostPath volume + volumeMount for the policy file (read-only) and for the log directory `/var/log/kubernetes/audit` (type `DirectoryOrCreate`).
6. Wait for the apiserver to come back (`kubectl get nodes` works again).
7. Run `kubectl get secret db-creds -n default -o yaml`.
8. Find that exact event in the audit log: verb `get`, resource `secrets`, name `db-creds`. Confirm its `level` is `RequestResponse` and that it contains `responseObject`.
9. Find any event for a non-secret request (for example `get pods`) and confirm its level is `Metadata` and it has no `responseObject`.

## Check your work
- `kubectl get --raw /healthz` returns `ok` after the restart.
- `/var/log/kubernetes/audit/audit.log` exists inside the node and grows.
- The `db-creds` get event shows `"level":"RequestResponse"`, `"stage":"ResponseComplete"`, `"verb":"get"`, `objectRef.name":"db-creds"`.
- Non-secret events show `"level":"Metadata"`.
- The kube-apiserver static pod in `kube-system` is Running with the new flags (`kubectl get pod -n kube-system -l component=kube-apiserver -o yaml | grep audit`).

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-06-enable-audit-logs.md](../../answers/week-06-monitoring-logging-runtime-security/day-06-enable-audit-logs.md) — Attempt the task first; only then open the answer.

## Cleanup
Keep audit logging enabled for Day 7. After Day 8, optionally restore the backup manifest to disable it.
