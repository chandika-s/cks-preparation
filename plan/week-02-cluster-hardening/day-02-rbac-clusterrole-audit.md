# Week 2 · Day 2 (Oct 1) — RBAC: ClusterRole, aggregation, auditing existing bindings
**Domain:** Cluster Hardening (15%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Grant access to cluster-scoped resources with a ClusterRole and ClusterRoleBinding.
- Audit which bindings grant `cluster-admin` and who the subjects are.
- Understand ClusterRole aggregation via `aggregationRule`.

## Theory
- Use a `ClusterRole` for cluster-scoped resources (nodes, persistentvolumes, namespaces, storageclasses, CRDs), for non-resource URLs (`/healthz`), or as a reusable role template bound per namespace through a `RoleBinding`.
- A `ClusterRoleBinding` grants the ClusterRole across all namespaces and cluster-scoped resources. A `RoleBinding` to a ClusterRole limits it to one namespace.
- Aggregation: a ClusterRole with `aggregationRule.clusterRoleSelectors` has its `rules` filled automatically by the controller from every ClusterRole whose labels match. Built-in `admin`, `edit`, `view` aggregate from labels like `rbac.authorization.k8s.io/aggregate-to-view: "true"`. Do not put `rules` by hand in an aggregated role; they are overwritten.
- Auditing tools: `kubectl auth can-i --list --as=<user> [-n ns]`, `kubectl get clusterrolebindings -o json | jq`, `kubectl describe clusterrolebinding <name>`, `kubectl get rolebindings,clusterrolebindings -A -o wide`.
- Default `cluster-admin` bindings on kubeadm/kind: `cluster-admin` (group `system:masters`) and `kubeadm:cluster-admins` (group `kubeadm:cluster-admins`). Any extra binding to a user, SA or `system:authenticated` is a finding.
- Key jq shape: `.items[] | select(.roleRef.name=="cluster-admin") | {name: .metadata.name, subjects}`.

## Prerequisites
None. (`jq` installed on the host.)

## Exam-style question
Context: the kind-cks cluster is running with its default RBAC bindings. Task: audit every ClusterRoleBinding and RoleBinding that grants `cluster-admin` and identify any subject that should not have it. Then create ServiceAccount `node-viewer` in namespace `default` with read-only access (get, list) to nodes and persistentvolumes through ClusterRole `node-pv-viewer` and ClusterRoleBinding `node-viewer-binding`. Requirements: do not modify or delete any existing binding; the ServiceAccount must not be able to delete nodes, list pods in `kube-system`, or read secrets in any namespace.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. List every ClusterRoleBinding in the cluster whose `roleRef.name` is `cluster-admin`, printing the binding name and its subjects (kind, name, namespace). Also list any RoleBindings in any namespace that reference `cluster-admin`. Record which subjects are expected (built-in) and which would be a finding.
2. Create a ClusterRole `node-pv-viewer` allowing only `get` and `list` on `nodes` and `persistentvolumes`.
3. Create ServiceAccount `node-viewer` in namespace `default` and bind `node-pv-viewer` to it with a ClusterRoleBinding named `node-viewer-binding`.
4. Verify as `system:serviceaccount:default:node-viewer`:
   - `list nodes` yes; `list persistentvolumes` yes; `delete nodes` no; `list pods -n kube-system` no; `list secrets -A` no.
5. Stretch (aggregation): create ClusterRole `monitoring-aggregate` with an `aggregationRule` selecting label `rbac.cks/aggregate-to-monitoring: "true"`. Create two small ClusterRoles carrying that label: one allowing `get,list` on `pods`, one allowing `get,list` on `services`. Show that `monitoring-aggregate` ends up with both rules without you editing it.

## Check your work
- Step 1 output includes the built-in `cluster-admin` and `kubeadm:cluster-admins` bindings and no unexpected user/SA subjects.
- `kubectl describe clusterrole node-pv-viewer` shows two resources with `[get list]`.
- The five `can-i` answers are yes / yes / no / no / no.
- `kubectl get clusterrole monitoring-aggregate -o yaml` shows populated `rules` for `pods` and `services`.

## Answer
[answers/week-02-cluster-hardening/day-02-rbac-clusterrole-audit.md](../../answers/week-02-cluster-hardening/day-02-rbac-clusterrole-audit.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete the objects created in steps 2–5 (ClusterRoles, ClusterRoleBinding, SA `node-viewer`) at end of week; they are harmless to later days.
