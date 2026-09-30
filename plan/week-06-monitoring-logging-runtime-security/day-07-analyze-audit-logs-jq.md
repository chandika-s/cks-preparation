# Week 6 · Day 7 (Nov 3) — Analyze audit logs for suspicious activity
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Generate representative audit noise as several simulated users.
- Extract deletes, a specific user's requests, and 403 responses with `jq`.
- Record reusable one-liner filters.

## Theory
Each audit line is a JSON `Event`. Fields to know:

- `verb` (`get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`), `stage`, `level`, `requestURI`, `requestReceivedTimestamp`, `stageTimestamp`.
- `user.username`, `user.groups`; with impersonation (`--as`), `user` is the real caller and `impersonatedUser.username` is the impersonated identity. Filter on both.
- `objectRef.resource`, `.namespace`, `.name`, `.subresource` (e.g. `exec`).
- `sourceIPs`, `userAgent`.
- `responseStatus.code` (200, 201, 403, 404...), `responseStatus.reason`.
- `annotations["authorization.k8s.io/decision"]` = `allow`/`forbid`.

jq basics: `select(cond)`, `-c` compact output, `-r` raw strings, `.a.b`, `?` to tolerate missing fields, `//` default, `| {a: .x, b: .y}` projection, `group_by`, `-s` slurp, `contains`, `test("regex")`. Suspicious patterns: `exec`/`attach` on pods, secret `list` cluster-wide, `delete` of pods/RBAC, repeated 403s from one identity, `create` of `clusterrolebindings`, unknown `sourceIPs`.

## Prerequisites
Day 6: audit logging enabled (policy + `--audit-log-path=/var/log/kubernetes/audit/audit.log`). `jq` installed on the host.

## Exam-style question
Context: audit logging is enabled on the cluster, and namespace `audit-lab` holds pods `p1` and `p2`, Secret `s1`, Role `pod-manager` bound to user `bob`, and user `alice` with no permissions. Task: generate activity as `alice`, `bob` and the admin, then copy the audit log to `workspace/week-06/audit.log` and use `jq` to answer questions about it. Requirements: save each filter and its result count in `workspace/week-06/day-07-filters.txt` for: all deletes in `audit-lab`, all requests involving `alice`, all `403` responses summarized by user, verb and resource, all pod `exec` events, and secret access by anyone other than `kubernetes-admin` or `system:*`; state which identity tried to read secrets cluster-wide and whether it succeeded.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Create namespace `audit-lab` with pods `p1`, `p2` (image `nginx`) and Secret `s1`.
2. Create Role `pod-manager` in `audit-lab` (verbs `get,list,delete` on `pods`) and RoleBinding `bob-pod-manager` binding it to user `bob`. Give user `alice` no permissions.
3. Generate noise (all with impersonation using `--as`):
   - `alice`: `get pods -n audit-lab`, `list secrets -n audit-lab`, `get secrets -A`.
   - `bob`: `get pods -n audit-lab`, `list pods -n audit-lab`, `delete pod p2 -n audit-lab`, `get secrets -n audit-lab`.
   - Yourself (admin): `delete secret s1 -n audit-lab`, `exec` into `p1` (`kubectl exec p1 -n audit-lab -- true`).
4. Copy the audit log to `workspace/week-06/audit.log` on the host.
5. With `jq`, produce and save (one per line) in `workspace/week-06/day-07-filters.txt` the exact filter and its result count for:
   a. all `delete` events in `audit-lab` (show time, actor, impersonated user, resource, name, response code),
   b. all requests involving user `alice` (real or impersonated),
   c. all requests that returned `403`, summarized by impersonated user, verb and resource,
   d. all `exec` events on pods,
   e. every request where `secrets` were accessed by anyone other than `kubernetes-admin` or `system:*` identities.
6. Answer: which identity attempted to read secrets cluster-wide, and did it succeed?

## Check your work
- (a) shows two deletes: pod `p2` by `bob` (200) and secret `s1` by admin (200).
- (b) shows only `alice` events with 403 statuses.
- (c) lists alice's three denied requests and bob's denied `get secrets`.
- (d) shows the exec on `p1` with `subresource` `exec`.
- (e) lists alice and bob secret accesses with 403.
- `day-07-filters.txt` contains five working one-liners.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-07-analyze-audit-logs-jq.md](../../answers/week-06-monitoring-logging-runtime-security/day-07-analyze-audit-logs-jq.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns audit-lab`
