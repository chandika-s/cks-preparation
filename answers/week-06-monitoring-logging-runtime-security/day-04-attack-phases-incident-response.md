# Week 6 · Day 4 (Oct 31) — Investigate and identify phases of an attack — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-04-attack-phases-incident-response.md](../../plan/week-06-monitoring-logging-runtime-security/day-04-attack-phases-incident-response.md)

## Solution
Apply the setup manifest (`kubectl apply -f workspace/week-06/day-04-setup.yaml`), then:
```
POD=$(kubectl get pod -n prod -l app=web -o jsonpath='{.items[0].metadata.name}')
```
1. Isolate:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine-web
  namespace: prod
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: [Ingress, Egress]
```
```
kubectl apply -f quarantine-web.yaml
```
2. Evidence (before deleting):
```
mkdir -p workspace/week-06/day-04-evidence
kubectl logs -n prod $POD > workspace/week-06/day-04-evidence/pod.log
kubectl describe pod -n prod $POD > workspace/week-06/day-04-evidence/describe.txt
kubectl get events -n prod --sort-by=.lastTimestamp > workspace/week-06/day-04-evidence/events.txt
```
3. Find bindings:
```
kubectl get clusterrolebindings,rolebindings -A -o wide | grep web-sa
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.subjects[]? | .kind=="ServiceAccount" and .name=="web-sa" and .namespace=="prod") | .metadata.name + " -> " + .roleRef.name'
kubectl auth can-i --list --as=system:serviceaccount:prod:web-sa
kubectl describe clusterrole secret-reader-all
```
Result: ClusterRoleBinding `web-secret-reader` grants `secret-reader-all` (get/list/watch secrets cluster-wide).
4. Revoke:
```
kubectl delete clusterrolebinding web-secret-reader
kubectl patch sa web-sa -n prod -p '{"automountServiceAccountToken": false}'
```
5. Replace:
```
kubectl delete pod -n prod $POD
kubectl get pods -n prod
```
6. `notes.txt` example:
```
Initial access: web app compromised (assumed). Execution: shell spawned in web pod (Falco).
Privilege escalation/discovery: stolen SA token, over-broad ClusterRoleBinding web-secret-reader.
Impact/exfiltration risk: Secrets listed cluster-wide; all Secrets must be rotated.
```

## Expected output
```
$ kubectl auth can-i list secrets -A --as=system:serviceaccount:prod:web-sa
no
$ kubectl get pods -n prod
NAME         READY   STATUS    RESTARTS   AGE
web-6c9d-xyz  1/1    Running   0          15s
```
Note: the SA patch only affects pods created after it; the replacement pod in step 5 is created after the patch, so it has no token mounted. Confirm with `kubectl exec -n prod <new-pod> -- ls /var/run/secrets/kubernetes.io` failing (no such directory).

## Why it works
Deny-all NetworkPolicy blocks C2 and lateral movement immediately without destroying evidence. Deleting the ClusterRoleBinding removes the privilege for any token the SA holds; the stolen bound token also dies with the pod. The Deployment recreates the pod from the clean template; the label still matches the policy, so it stays isolated until you decide otherwise.

## Common mistakes / exam gotchas
- Deleting the pod first: evidence lost; the Deployment respawns it un-isolated if the policy is not in place.
- Only checking RoleBindings in `prod`; the grant was a ClusterRoleBinding.
- Deleting the ServiceAccount instead of the binding: the Deployment then fails to create pods.
- Egress-only or ingress-only policy: set both `policyTypes`.
- Forgetting the patch must precede the pod deletion to affect the replacement.
- Real incidents: also rotate every Secret the attacker could read. The exam usually stops at RBAC and pod.
- Optional: relabel the pod (`kubectl label pod $POD -n prod app-`) to detach it from the ReplicaSet and keep it for forensics, rather than deleting.

## Cleanup
```
kubectl delete ns prod
kubectl delete clusterrole secret-reader-all
```
