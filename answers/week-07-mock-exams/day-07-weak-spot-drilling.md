# Week 7 · Day 7 (Nov 11) — Weak-spot drilling — Answers
Task: [plan/week-07-mock-exams/day-07-weak-spot-drilling.md](../../plan/week-07-mock-exams/day-07-weak-spot-drilling.md)

Your own miss log defines the exact content of this day; this file gives the review checklist, the most likely weak spots from Days 1-5 with their fix-in-one-line and answer-file references, and a pre-flight checklist to reduce careless misses.

## Solution

### Drill procedure (per item)
1. Set a timer; read only the one-line gap.
2. Rebuild from memory in a fresh namespace with new names.
3. Verify with the exam-style check (`can-i`, `curl`, `jq`, `etcdctl`, `describe`, `logs`).
4. Compare with the answer file; if different, decide whether yours was also valid.
5. If not clean, study the mapped theory, then repeat with new names. Only mark clean when a run is correct first time and inside the target time.

### Most likely weak spots and the one-line fix

| Source task | Typical failure | One-line fix | Reference answer |
|---|---|---|---|
| Day 1 NetworkPolicy | Blocked DNS after default-deny egress | Add `allow-dns` to kube-system UDP+TCP 53 | day-01 Task 1 |
| Day 1 NetworkPolicy | Selector AND vs OR | Same list item = AND; separate items = OR | day-01 Task 1 |
| Day 1 RBAC | Two rules in one Role via imperative command | Use YAML for multi-rule Roles; `resourceNames` on `get` only | day-01 Task 2 |
| Day 1 Encryption | API server does not come back | Check flag path, hostPath mount, YAML indentation; restore backup outside manifests | day-01 Task 3 |
| Day 1 Encryption | Data still plaintext | `identity` last; `kubectl get secrets -A -o json \| kubectl replace -f -` | day-01 Task 3 |
| Day 1 SA hygiene | Default token still mounted | `automountServiceAccountToken: false` on pod overrides SA; projected token needs its own volume | day-01 Task 5 |
| Day 2 CIS | Fix applied to wrong node or not restarted | Control plane: edit manifest; kubelet: edit config and `systemctl restart kubelet`; both nodes | day-02 Task 1 |
| Day 2 PSA | Admission error only visible in ReplicaSet events | `kubectl describe rs`; use `--dry-run=server` | day-02 Task 2 |
| Day 2 PSA | `runAsNonRoot` fails on root image | Use unprivileged image or set numeric `runAsUser` | day-02 Task 2 |
| Day 2 Trivy | Wrong severity or counts read from the wrong section | `--severity`, `-f json`, `jq` count of `.Results[].Vulnerabilities` | day-02 Task 3 |
| Day 2 Dockerfile | `ADD`, root user, `latest` | Pinned slim base, `COPY`, numeric `USER` | day-02 Task 5 |
| Day 3 Falco | Rule not loaded / syntax error / no restart | `falco -V`, `rollout restart ds/falco`, grep logs | day-03 Task 1 |
| Day 3 audit | Looking at wrong stage or user | `stage=="ResponseComplete"`; `impersonatedUser` vs `user` | day-03 Task 2 |
| Day 3 immutability | nginx crashes with read-only root | Unprivileged image + `/tmp` emptyDir | day-03 Task 3 |
| Day 3 IR | Evidence lost | Contain, save YAML/logs, then delete | day-03 Task 5 |
| Day 4 Ingress | Cert not served | Secret same namespace; `tls.hosts` = rule host; `ingressClassName` set | day-04 Task 1 |
| Day 4 seccomp | `CreateContainerError` | Relative `localhostProfile`; profile on the pod's node | day-04 Task 2 |
| Day 4 AppArmor | Trying to run it on kind | Write the securityContext + node commands; state the limitation | day-04 Task 3 |
| Day 4 Kyverno | Pattern does not match | Quote `*`/`!`; image string matched as written; scope namespaces | day-04 Task 4 |
| Day 5 cosign | Verify passes/fails unexpectedly | Sign and verify by digest; `--tlog-upload=false`/`--insecure-ignore-tlog=true` for local registry | day-05 Task 1 |
| Day 5 Quota | Pods rejected for missing resources | LimitRange defaults; `default` = limits, `defaultRequest` = requests | day-05 Task 2 |
| Day 5 Upgrade | Order recited wrong | backup, kubeadm pkg, plan, apply, drain, kubelet+kubectl, restart, uncordon; worker: `upgrade node` | day-05 Task 3 |
| Day 5 Metadata | Policy does not block | `ipBlock cidr 0.0.0.0/0` with `except`; check for other allowing policies | day-05 Task 4 |

### Pre-flight checklist (read before every task)
1. `kubectl config current-context` matches what the question says; namespace stated.
2. Required output path/name written down.
3. Backup any control-plane manifest to a directory outside `/etc/kubernetes/manifests` before editing.
4. Scaffold with `$do`, never hand-write a full manifest if a generator exists.
5. Verify with the check that proves the requirement, not just `apply` success.
6. Note time; leave at 8 minutes.

### Suggested cheatsheet additions (if they were gaps)
- `kubectl auth can-i <verb> <resource>[/name] --as=system:serviceaccount:<ns>:<sa> -n <ns>`
- etcd read: `kubectl -n kube-system exec etcd-<node> -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get <key>`
- `kubectl apply --dry-run=server -f x.yaml` for PSA/admission checks
- `jq -c 'select(.verb=="delete" and .objectRef.resource=="secrets")' audit.log`
- `cosign sign --key cosign.key --tlog-upload=false <image@digest>` / `cosign verify --key cosign.pub --insecure-ignore-tlog=true <image>`
- Drain: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`

## Expected output
A drill tracker where each row shows a clean, timed attempt; three weakest tasks completed inside 30 minutes; an exit gate fully ticked.

## Why it works
Repeating the exact failure under time pressure, with changed specifics, tests skill rather than memory of one answer; the checklist lines convert repeated errors into habits.

## Common mistakes / exam gotchas
- Marking an item clean after reading the solution first.
- Repeating with identical names so you copy from shell history.
- Drilling only your favourite topics.
- Leaving leftover namespaces or policies that make the next drill pass or fail for the wrong reason.
- Moving to Week 8 with unresolved items "because the score was decent".

## Cleanup
```
kubectl get ns
kubectl delete ns <lab namespaces>
```
Remove stray backups from `/etc/kubernetes/manifests` on `cks-control-plane`.
