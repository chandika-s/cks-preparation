# Week 7 · Day 3 (Nov 7) — Mixed set: Falco + audit logs + immutability
**Domain:** Monitoring, Logging and Runtime Security (20%) + Minimize Microservice Vulnerabilities (20%) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Write and load a custom Falco rule and prove it fires.
- Query Kubernetes audit logs with `jq` to answer investigative questions quickly.
- Produce a fully hardened, immutable pod spec and audit the cluster for pods that are not.
- Run a short incident-response sequence that preserves evidence.

## Theory
**Falco rule anatomy.** A rule has `rule`, `desc`, `condition`, `output`, `priority` (EMERGENCY..DEBUG), optional `tags`, `enabled`, `exceptions`. Conditions use fields (`proc.name`, `proc.cmdline`, `user.name`, `evt.type`, `fd.name`, `container.id`, `container.image.repository`, `k8s.ns.name`, `k8s.pod.name`) and default macros/lists from `falco_rules.yaml` (`spawned_process`, `container`, `open_read`, `sensitive_files`, `shell_procs`). Output format strings interpolate `%field`. Custom rules go in `/etc/falco/rules.d/` or `falco_rules.local.yaml` (loaded after defaults; can override with `append: true`). Validate with `falco -V <file>`. Helm chart: `customRules:` values; then restart the DaemonSet. Alerts appear in the Falco container log. On kind (Docker Desktop, macOS) driver support depends on the Linux VM kernel; use the modern eBPF driver as in Week 6.

**Audit logs.** Policy (`audit.k8s.io/v1` `Policy`) rules are first-match; levels `None|Metadata|Request|RequestResponse`; `omitStages`. API server flags: `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`; both policy and log dir need hostPath mounts. Each JSON-lines event has `user.username`, `user.groups`, `verb`, `objectRef.{resource,subresource,namespace,name}`, `responseStatus.code`, `requestURI`, `sourceIPs`, `requestReceivedTimestamp`, `impersonatedUser` (when `--as` is used, `user` is the real caller). Useful patterns: `jq -c 'select(.verb=="delete")'`, `select(.responseStatus.code==403)`, `select(.objectRef.subresource=="exec")`.

**Immutability.** `readOnlyRootFilesystem: true` plus `emptyDir` for needed writable paths; `allowPrivilegeEscalation: false`; `capabilities.drop: [ALL]`; `runAsNonRoot`; seccomp `RuntimeDefault`; no `privileged`, no `hostPath`; no runtime package installs; automount SA token off if unused. Detect drift/mutable workloads by querying pod specs with `jq`.

**Incident response order.** Contain (isolate network), preserve evidence (logs, `get -o yaml`, Falco/audit extracts), remove access (RBAC/SA), then eradicate (delete/recreate from clean image).

## Prerequisites
- Falco installed in namespace `falco` (Week 6 Day 1), producing the default "Terminal shell in container" alert.
- API server audit logging enabled per Week 6 Day 6 (policy logs `secrets` at `RequestResponse`, everything else at least `Metadata`; log at `/var/log/kubernetes/audit/audit.log` on `cks-control-plane`; adjust paths below if yours differs). If not enabled, do that first and count it against your time.
- `jq` on host.

## Task
Total 90 min / 100 points.

**Setup (not timed):**
```
kubectl create ns web-prod
kubectl -n web-prod run intruder --image=busybox:1.36 --labels app=web -- sleep 3600
kubectl -n web-prod expose pod intruder --port 80 --name web-svc
kubectl create ns locked
kubectl -n locked run legacy-app --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"legacy-app","image":"nginx:1.27","securityContext":{"privileged":true}}]}}'
```

### Task 1 — Custom Falco rule (20 min, 25 pts)
1. Add a rule named `Network Tool Run In Web Prod` with priority `WARNING`, tag `mock`, that fires when a process named `wget` or `curl` is spawned in any container in namespace `web-prod`.
2. Output must be exactly: `NET_TOOL_IN_POD ns=<namespace> pod=<pod> user=<user> cmd=<full command line> image=<image repo>`.
3. Load it so it survives Falco pod restarts (Helm values or ConfigMap, matching your Week 6 setup) and restart Falco.
4. Trigger it by running `wget -qO- -T2 http://kubernetes.default.svc` inside `web-prod/intruder`, and save the matching Falco log line to `/tmp/falco-hit.txt`.

### Task 2 — Audit log queries with jq (20 min, 25 pts)
Generate events first:
```
kubectl create ns audit-lab
kubectl -n audit-lab create secret generic s1 --from-literal=k=v
kubectl -n audit-lab get secret s1
kubectl -n audit-lab delete secret s1
kubectl -n audit-lab get pods --as=mallory
kubectl -n web-prod exec intruder -- id
```
Copy the log to the host (`docker cp cks-control-plane:/var/log/kubernetes/audit/audit.log /tmp/audit.log`), then, using `jq` only:
1. `/tmp/audit-q1.txt`: one compact JSON object per delete of a Secret with fields `user`, `ns`, `name`, `time`.
2. `/tmp/audit-q2.txt`: every request answered with HTTP 403, showing `user`, `impersonated` user (or null), `verb`, `uri`, `code`.
3. `/tmp/audit-q3.txt`: every `exec` into a pod (subresource `exec`) with `user`, `ns`, `pod`.
4. `/tmp/audit-q4.txt`: the number of events per `verb` across the whole file, sorted descending.
5. In one sentence in `/tmp/audit-q5.txt`, state which query shows who caused the 403, and why `user` differs from `impersonated`.

### Task 3 — Hardened pod (20 min, 20 pts)
In namespace `locked`, create Pod `vault-ui` with image `nginxinc/nginx-unprivileged:1.27`:
1. Read-only root filesystem, no privilege escalation, all capabilities dropped, runs as non-root UID/GID 101, seccomp `RuntimeDefault`.
2. No ServiceAccount token mounted.
3. Writable only through an `emptyDir` at `/tmp`.
4. Container port 8080; must reach Ready.
5. Prove immutability: writing to `/usr/share/nginx/html/x` fails and writing to `/tmp/x` succeeds.

### Task 4 — Mutable workload audit (15 min, 15 pts)
1. Write `ns/name` of every pod outside `kube-system` that has at least one container where `readOnlyRootFilesystem` is not `true` to `/tmp/mutable-pods.txt`.
2. Write `ns/name` of every pod in the cluster with a privileged container (init containers included) to `/tmp/privileged-pods.txt`.
3. Remove the privilege risk from `locked/legacy-app`: recreate it as a non-privileged, non-root pod using `nginxinc/nginx-unprivileged:1.27` with the same name.

### Task 5 — Incident response (15 min, 15 pts)
Falco reports a shell in `web-prod/intruder`.
1. Contain: without deleting it, remove the pod from Service `web-svc` endpoints and block all its ingress and egress with a NetworkPolicy selecting `quarantine=true` (policy `quarantine`).
2. Preserve evidence: save `kubectl get pod -o yaml` and `kubectl logs` to `/tmp/evidence/intruder.yaml` and `/tmp/evidence/intruder.log`, and save the pod's Falco lines to `/tmp/evidence/falco.txt`.
3. Eradicate: delete the pod.

## Check your work
- Task 1: Falco log contains a line beginning with the rule's output string with ns=web-prod, pod=intruder; `falco -V` reports the file valid; rule persists after `kubectl -n falco rollout restart ds/falco`.
- Task 2: q1 shows one record for `s1` by `kubernetes-admin`; q2 shows `impersonated` = `mallory` with code 403; q3 lists `intruder`; q4 sorted numerically.
- Task 3: pod Ready; `touch` on html path returns `Read-only file system`; `kubectl get pod vault-ui -o yaml` shows all settings; no `/var/run/secrets/kubernetes.io/serviceaccount`.
- Task 4: `legacy-app` (old) appears in both files before the fix; after, `locked/legacy-app` has no `privileged`.
- Task 5: `web-svc` endpoints empty, connectivity from another pod to the intruder blocked before deletion, evidence files non-empty.

## Answer
[answers/week-07-mock-exams/day-03-falco-audit-immutability.md](../../answers/week-07-mock-exams/day-03-falco-audit-immutability.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns web-prod locked audit-lab
rm -rf /tmp/evidence
```
Remove the custom rule from Falco values if you do not want it to keep alerting.
