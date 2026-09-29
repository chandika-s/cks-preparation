# Week 2 · Day 2 (Oct 1) — RBAC: ClusterRole, aggregation, auditing existing bindings — Answers
Task: [plan/week-02-cluster-hardening/day-02-rbac-clusterrole-audit.md](../../plan/week-02-cluster-hardening/day-02-rbac-clusterrole-audit.md)

## Solution
1. Audit:
```
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name + " -> " + ([.subjects[]? | .kind + "/" + .name + (if .namespace then "@" + .namespace else "" end)] | join(", "))'
kubectl get rolebindings -A -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.namespace + "/" + .metadata.name'
kubectl describe clusterrolebinding cluster-admin
kubectl get clusterrolebindings -o wide | grep cluster-admin
```
2. ClusterRole:
```
kubectl create clusterrole node-pv-viewer --verb=get,list --resource=nodes,persistentvolumes
```
3. SA and binding:
```
kubectl create serviceaccount node-viewer -n default
kubectl create clusterrolebinding node-viewer-binding --clusterrole=node-pv-viewer --serviceaccount=default:node-viewer
```
4. Verify:
```
SA=system:serviceaccount:default:node-viewer
kubectl auth can-i list nodes --as=$SA
kubectl auth can-i list persistentvolumes --as=$SA
kubectl auth can-i delete nodes --as=$SA
kubectl auth can-i list pods -n kube-system --as=$SA
kubectl auth can-i list secrets -A --as=$SA
```
5. Aggregation:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-aggregate
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.cks/aggregate-to-monitoring: "true"
rules: []
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-pods
  labels:
    rbac.cks/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-services
  labels:
    rbac.cks/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
```
```
kubectl apply -f agg.yaml
kubectl get clusterrole monitoring-aggregate -o yaml
```

## Expected output
Audit (abbreviated, kind):
```
cluster-admin -> Group/system:masters
kubeadm:cluster-admins -> Group/kubeadm:cluster-admins
```
Other installed add-ons may appear; judge each. `can-i` answers: yes, yes, no, no, no (last one may print `no`). `monitoring-aggregate` shows `rules` for `pods` and `services`.

## Why it works
A ClusterRoleBinding to a ClusterRole gives rights on cluster-scoped resources, which Roles cannot express. The RBAC controller reconciles aggregated ClusterRole rules from label selectors.

## Common mistakes / exam gotchas
- Using a Role/RoleBinding for nodes or PVs: cluster-scoped resources cannot be granted by namespaced Roles.
- `jq` on `.subjects` fails when it is null; use `.subjects[]?`.
- Auditing only ClusterRoleBindings: `cluster-admin` can also be granted through namespaced RoleBindings (line 8 query), and broad `admin`/`edit` bindings deserve a look too.
- Watch for bindings to `system:authenticated` or `system:unauthenticated` groups: a serious finding.
- Editing `rules` of an aggregated role manually; the controller overwrites them.
- Remediate an over-broad binding with `kubectl delete clusterrolebinding <name>` (built-in kubeadm ones should be left alone).

## Cleanup
```
kubectl delete clusterrolebinding node-viewer-binding
kubectl delete clusterrole node-pv-viewer monitoring-aggregate monitoring-pods monitoring-services
kubectl delete sa node-viewer -n default
```
