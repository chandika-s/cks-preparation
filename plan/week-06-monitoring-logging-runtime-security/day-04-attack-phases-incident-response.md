# Week 6 · Day 4 (Oct 31) — Investigate and identify phases of an attack
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Map symptoms to attack phases.
- Isolate, investigate, and remediate a compromised pod under time pressure (20 min).
- Revoke an over-privileged ServiceAccount binding and replace the pod.

## Theory
Kill-chain style sequence in Kubernetes:
1. Initial access: exposed service, vulnerable app, leaked secret/kubeconfig.
2. Execution: shell or binary run in a container (Falco: "Terminal shell in container").
3. Privilege escalation: ServiceAccount token theft (`/var/run/secrets/kubernetes.io/serviceaccount/token`), privileged pod, `hostPath` mount, over-broad RBAC.
4. Lateral movement: reaching other pods/services over an unrestricted flat network, using the API with the stolen token.
5. Exfiltration/impact: reading Secrets, outbound data transfer, crypto-mining.

Response order on the exam: contain first (NetworkPolicy), preserve evidence (logs, describe, events) before deleting anything, remove the privilege (RBAC), then evict/replace the workload.

Key commands: `kubectl logs`, `kubectl describe`, `kubectl get events`, `kubectl get clusterrolebindings,rolebindings -A -o wide`, `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>`, `kubectl delete clusterrolebinding`. Bound ServiceAccount tokens (projected, default) are tied to the pod and become invalid when the pod is deleted; still remove the binding since the replacement pod gets a new token with the same rights. A NetworkPolicy with `podSelector` and both `policyTypes` but no rules denies all traffic to and from matching pods (enforced by Calico here).

## Prerequisites
Day 1 Falco optional (alerts add evidence). Calico enforces NetworkPolicy on `kind-cks`.

## Exam-style question
Context: Falco reported unexpected shells in the pod of Deployment `web` in namespace `prod`, and the pod's ServiceAccount `web-sa` was used to list Secrets cluster-wide. Task: contain and remediate the incident without disturbing other workloads. Requirements: isolate the compromised pods with a NetworkPolicy named `quarantine-web` before anything else; save pod logs, `describe` output and namespace events to `workspace/week-06/day-04-evidence/`; remove every RBAC grant that gives `web-sa` the excess permission and ensure its token is no longer auto-mounted in future pods; replace the compromised pod with a clean one; write a 3-line incident note mapping events to attack phases in `workspace/week-06/day-04-evidence/notes.txt`.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Setup (given scenario; apply as-is):
```yaml
apiVersion: v1
kind: Namespace
metadata: {name: prod}
---
apiVersion: v1
kind: ServiceAccount
metadata: {name: web-sa, namespace: prod}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: secret-reader-all}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: web-secret-reader}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: secret-reader-all}
subjects:
- {kind: ServiceAccount, name: web-sa, namespace: prod}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: prod}
spec:
  replicas: 1
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      serviceAccountName: web-sa
      containers:
      - {name: web, image: nginx:1.27, ports: [{containerPort: 80}]}
```
Scenario (timed, 20 min): pod `web-<hash>` in namespace `prod` (Deployment `web`) is spawning unexpected shells per a Falco alert, and its ServiceAccount token was used to list Secrets cluster-wide two minutes ago. Do, in order:
1. Isolate the pod with a NetworkPolicy `quarantine-web` in `prod` that denies all ingress and egress for pods labelled `app=web`.
2. Collect evidence: save the pod's logs and `kubectl describe` output, plus namespace events, to `workspace/week-06/day-04-evidence/`.
3. Identify every binding that gives ServiceAccount `prod/web-sa` its excess permissions (check both ClusterRoleBindings and RoleBindings across all namespaces), and record what they grant.
4. Revoke the excess permission. Also stop the ServiceAccount from having its token auto-mounted in future pods.
5. Delete the compromised pod so the Deployment reschedules a clean one.
6. Write a 3-line incident note in `workspace/week-06/day-04-evidence/notes.txt` mapping what happened to attack phases.

## Check your work
- `kubectl auth can-i list secrets -A --as=system:serviceaccount:prod:web-sa` prints `no`.
- The replacement pod has a new name and is `Running`; a connection from it to anywhere times out (still quarantined).
- The evidence directory holds logs, describe, and events files.
- `kubectl get sa web-sa -n prod -o yaml` shows `automountServiceAccountToken: false`.
- The old pod is gone.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-04-attack-phases-incident-response.md](../../answers/week-06-monitoring-logging-runtime-security/day-04-attack-phases-incident-response.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns prod; kubectl delete clusterrole secret-reader-all` (the ClusterRoleBinding is already removed by step 4).
