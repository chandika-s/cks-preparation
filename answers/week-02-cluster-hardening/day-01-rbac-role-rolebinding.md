# Week 2 · Day 1 (Sep 30) — RBAC: Role & RoleBinding — Answers
Task: [plan/week-02-cluster-hardening/day-01-rbac-role-rolebinding.md](../../plan/week-02-cluster-hardening/day-01-rbac-role-rolebinding.md)

## Solution
1. Namespace and SA:
```
kubectl create namespace rbac-lab
kubectl create serviceaccount pod-reader-sa -n rbac-lab
```
2. Role:
```
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n rbac-lab
```
Equivalent YAML:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```
3. RoleBinding:
```
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=rbac-lab:pod-reader-sa -n rbac-lab
```
Equivalent YAML:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: rbac-lab
subjects:
- kind: ServiceAccount
  name: pod-reader-sa
  namespace: rbac-lab
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```
4. Verify:
```
SA=system:serviceaccount:rbac-lab:pod-reader-sa
kubectl auth can-i list pods --as=$SA -n rbac-lab
kubectl auth can-i delete pods --as=$SA -n rbac-lab
kubectl auth can-i list pods --as=$SA -n default
kubectl auth can-i get secrets --as=$SA -n rbac-lab
```
5. Effective list:
```
kubectl auth can-i --list --as=$SA -n rbac-lab
```

## Expected output
```
yes
no
no
no
```
`--list` shows `pods  []  []  [get list watch]` plus default discovery entries (`selfsubjectreviews`, `selfsubjectaccessreviews`, `/api`, `/healthz`, ...) granted to all authenticated subjects via `system:basic-user` / `system:discovery`.

## Why it works
The authorizer (RBAC) finds RoleBindings in `rbac-lab` whose subject matches the impersonated user, resolves `roleRef`, and allows the request only if a rule matches verb, apiGroup and resource. No rule in `default` or for `secrets` means implicit deny.

## Common mistakes / exam gotchas
- `--serviceaccount` takes `<namespace>:<name>`, not just the name; omitting the namespace fails.
- Using `--user` in a binding for an SA (wrong subject kind), so nothing matches.
- Forgetting `-n` on `can-i` and querying `default`.
- `--as` for SAs needs the full `system:serviceaccount:<ns>:<name>` form.
- Granting `*` verbs or resources; exams check for least privilege.
- `roleRef` is immutable; to change it delete and recreate the binding.

## Cleanup
```
kubectl delete ns rbac-lab
```
