# Week 2 · Day 6 (Oct 5) — Combined RBAC + SA audit task — Answers
Task: [plan/week-02-cluster-hardening/day-06-rbac-sa-audit-timed.md](../../plan/week-02-cluster-hardening/day-06-rbac-sa-audit-timed.md)

## Solution
1. Find and delete:
```
kubectl get rolebindings -n payments -o wide
kubectl get rolebindings,clusterrolebindings -A -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | select(any(.subjects[]?; .name=="default" and .namespace=="payments")) | .kind + "/" + .metadata.name'
kubectl delete rolebinding payments-admin -n payments
```
2. ```
kubectl create role payments-reader --verb=get,list --resource=configmaps,secrets -n payments
```
3. ```
kubectl create serviceaccount payments-sa -n payments
kubectl create rolebinding payments-reader-binding --role=payments-reader --serviceaccount=payments:payments-sa -n payments
```
4. ```
kubectl set serviceaccount deployment payments-api payments-sa -n payments
kubectl rollout status deployment payments-api -n payments
```
`payments-sa` needs API access, so leave its automount at the default (true).
5. ```
kubectl patch serviceaccount default -n payments -p '{"automountServiceAccountToken": false}'
```
6. ```
P=system:serviceaccount:payments:payments-sa
D=system:serviceaccount:payments:default
kubectl auth can-i list configmaps --as=$P -n payments
kubectl auth can-i get secrets --as=$P -n payments
kubectl auth can-i delete secrets --as=$P -n payments
kubectl auth can-i list pods --as=$P -n payments
kubectl auth can-i list configmaps --as=$P -n default
kubectl auth can-i list secrets --as=$D -n payments
kubectl auth can-i delete deployments --as=$D -n payments
```

## Expected output
`yes yes no no no` for the first five, then `no no` for the `default` checks. `kubectl get rolebindings -n payments` lists only `payments-reader-binding`.

## Why it works
Deleting the RoleBinding removes the only source of `cluster-admin` for `default`; the new Role grants exactly the requested verbs/resources; the pod now runs as an identity whose only rights are those; automount off for `default` limits future pods.

## Common mistakes / exam gotchas
- Deleting the wrong binding (check `subjects` and `roleRef` first), or looking only at ClusterRoleBindings when the stray one is a RoleBinding.
- Creating the Role but binding it to `default` instead of the dedicated SA.
- Verifying before the deployment rolled out; `can-i` tests RBAC only, so also check the deployment's SA.
- Forgetting `-n payments` on Role/RoleBinding creation (lands in `default`).
- Wrong `--serviceaccount` format (needs `ns:name`).
- Granting more than asked (`watch`, `*`, other resources).

## Cleanup
```
kubectl delete ns payments
```
