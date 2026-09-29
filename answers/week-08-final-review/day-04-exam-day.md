# Week 8 · Day 4 (Nov 15) — Exam day — Answers
Back to task: [day-04-exam-day](../../plan/week-08-final-review/day-04-exam-day.md)

## Solution
Exam-tactics playbook.

**Morning**
- Eat, water, arrive at the desk 30 min early, system check, ID ready.
- Optional 10-min warm-up on `kind-cks`, for example: create namespace, default-deny NetworkPolicy, allow one ingress, test with `kubectl exec`; or a Role/RoleBinding with `kubectl auth can-i`. Stop at 10 min.

**First 2 minutes**
```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
```
Confirm editor (`vi`) and set `set expandtab shiftwidth=2 tabstop=2` in `~/.vimrc` if useful. Bookmark or open docs pages: NetworkPolicy, PSA, AppArmor/seccomp, audit policy, Ingress TLS, RuntimeClass.

**Time-boxing**
- 120 min, typically 15–20 tasks: about 6–7 min average.
- Pass 1: take tasks you can finish in under 5 min first, skim weights.
- Hard cap 10–12 min per task; flag and move on.
- Pass 2: flagged tasks, highest weight first.
- Last 10–15 min: re-verify, especially anything touching the control plane.

**Per-task loop**
1. `kubectl config use-context <ctx>` (copy from the question). Check with `k config current-context`.
2. Read the whole question; note names, namespaces, file paths, required values.
3. Work with generators and `$do`; edit YAML rather than typing it.
4. For node work: `ssh <node>`, `sudo -i`; return to the base node before the next context switch.
5. Verify with a proving command; only then move on.

**Control-plane edits (kube-apiserver, etcd)**
1. Back up the manifest first: `cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak` (outside the manifests directory).
2. Edit; wait for the pod to restart: `watch crictl ps | grep kube-apiserver`.
3. If it fails: `crictl logs <id>` or `/var/log/pods/`; restore the backup.

**Debugging heuristics**
- Pod Pending/rejected: `k describe`, `k get events --sort-by=.lastTimestamp`.
- Admission denied: read the message, fix the field named.
- NetworkPolicy: check label selectors and namespaceSelector `kubernetes.io/metadata.name`; remember DNS egress (UDP/TCP 53).
- Do not leave stray resources modified outside what was asked.

**Wrap-up**
- Re-verify flagged tasks, then end. Passing extends CKA to the new CKS expiration.

## Expected output
- Each task ends with a verification output matching the requirement; context confirmed before each; results within 24 h by email.

## Why it works
- Context discipline removes zero-credit mistakes; time-boxing protects the score of the easy tasks; partial credit rewards attempting everything.

## Common mistakes / exam gotchas
- Not switching context, or working in the wrong namespace.
- Spending 20 min on a single low-weight task.
- Editing manifests inside `/etc/kubernetes/manifests` with backup files left there (kubelet may load them).
- Forgetting to save the file or apply changes; not verifying pod restarts.
- Copying YAML from docs with wrong indentation; use `:set paste`.
- Deleting/recreating resources when the question says modify.
- Relying on memory for file paths that docs list.

## Cleanup
- None. Optionally delete warm-up resources on `kind-cks`.
