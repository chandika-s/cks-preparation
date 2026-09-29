# Week 6 · Day 7 (Nov 3) — Analyze audit logs for suspicious activity — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-07-analyze-audit-logs-jq.md](../../plan/week-06-monitoring-logging-runtime-security/day-07-analyze-audit-logs-jq.md)

## Solution
1-2. Setup:
```
kubectl create ns audit-lab
kubectl run p1 -n audit-lab --image=nginx
kubectl run p2 -n audit-lab --image=nginx
kubectl create secret generic s1 -n audit-lab --from-literal=k=v
kubectl create role pod-manager -n audit-lab --verb=get,list,delete --resource=pods
kubectl create rolebinding bob-pod-manager -n audit-lab --role=pod-manager --user=bob
```
3. Noise:
```
kubectl get pods -n audit-lab --as=alice
kubectl get secrets -n audit-lab --as=alice
kubectl get secrets -A --as=alice
kubectl get pods -n audit-lab --as=bob
kubectl delete pod p2 -n audit-lab --as=bob
kubectl get secrets -n audit-lab --as=bob
kubectl delete secret s1 -n audit-lab
kubectl wait --for=condition=Ready pod/p1 -n audit-lab
kubectl exec p1 -n audit-lab -- true
```
4. Copy:
```
mkdir -p workspace/week-06
docker exec cks-control-plane cat /var/log/kubernetes/audit/audit.log > workspace/week-06/audit.log
```
5. Filters (`L=workspace/week-06/audit.log`):

a. Deletes:
```
jq -c 'select(.verb=="delete" and .objectRef.namespace=="audit-lab") | {t:.requestReceivedTimestamp, actor:.user.username, as:.impersonatedUser.username, res:.objectRef.resource, name:.objectRef.name, code:.responseStatus.code}' $L
```
b. Alice (real or impersonated):
```
jq -c 'select(.user.username=="alice" or .impersonatedUser.username=="alice") | {t:.requestReceivedTimestamp, verb, uri:.requestURI, code:.responseStatus.code}' $L
```
c. 403s:
```
jq -c 'select(.responseStatus.code==403) | {as:(.impersonatedUser.username // .user.username), verb, res:.objectRef.resource, ns:.objectRef.namespace}' $L
```
d. exec:
```
jq -c 'select(.objectRef.subresource=="exec") | {t:.requestReceivedTimestamp, user:.user.username, pod:.objectRef.name, ns:.objectRef.namespace}' $L
```
e. Secrets accessed by non-admin/non-system identities:
```
jq -c 'select(.objectRef.resource=="secrets" and ((.impersonatedUser.username // .user.username) | (. != "kubernetes-admin" and (startswith("system:") | not)))) | {as:(.impersonatedUser.username // .user.username), verb, ns:.objectRef.namespace, code:.responseStatus.code}' $L
```
Count any with `| wc -l`, e.g. `jq -c '...' $L | wc -l`. Save them all to `workspace/week-06/day-07-filters.txt`.

6. Answer: `alice` ran `get secrets -A` (list across all namespaces); it failed with 403.

## Expected output
```
{"t":"2026-11-03T10:05:11.1Z","actor":"kubernetes-admin","as":"bob","res":"pods","name":"p2","code":200}
{"t":"...","actor":"kubernetes-admin","as":null,"res":"secrets","name":"s1","code":200}
{"as":"alice","verb":"list","res":"secrets","ns":null}
```
Note the actor for impersonated requests is the admin, and `as` holds bob/alice. The admin username on kind is `kubernetes-admin`.

## Why it works
Impersonation is recorded in `impersonatedUser` while `user` remains the authenticated caller, so per-user hunting must check both. `responseStatus.code` is present at `ResponseComplete` at `Metadata` level or above. The `//` operator supplies the fallback when no impersonation exists.

## Common mistakes / exam gotchas
- Filtering only `.user.username` and missing all impersonated activity.
- `select(.responseStatus.code==403)` errors on events with no `responseStatus`? It does not error; missing is `null` and does not match. Use `?` when indexing arrays (`.sourceIPs[]?`).
- `jq` on the whole file when the log has partial last line: use `jq -c . 2>/dev/null` or `tail -n` first.
- Filtering by `.verb=="delete"` misses `deletecollection`.
- Metadata level omits `requestObject`/`responseObject`; you cannot see bodies unless the policy logged at Request/RequestResponse.
- `grep` works for quick checks (`grep '"code":403'`) but is less precise.
- On the exam the log may be at a path given in the question; read the apiserver manifest to find `--audit-log-path`.

## Cleanup
```
kubectl delete ns audit-lab
```
Optionally restore the original apiserver manifest from the Day 6 backup to stop audit logging.
