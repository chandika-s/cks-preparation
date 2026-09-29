# Week 2 · Day 3 (Oct 2) — Service account hygiene — Answers
Task: [plan/week-02-cluster-hardening/day-03-service-account-hygiene.md](../../plan/week-02-cluster-hardening/day-03-service-account-hygiene.md)

## Solution
1. `kubectl create namespace sa-lab`
2. `kubectl patch serviceaccount default -n sa-lab -p '{"automountServiceAccountToken": false}'`
3. ```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: sa-lab
automountServiceAccountToken: true
```
```
kubectl apply -f app-sa.yaml
```
4. Deployments:
```
kubectl create deployment no-api --image=busybox:1.36 -n sa-lab -- sleep 3600
kubectl create deployment needs-api --image=busybox:1.36 -n sa-lab --dry-run=client -o yaml -- sleep 3600 > needs-api.yaml
```
Edit `needs-api.yaml`, adding under `spec.template.spec`:
```yaml
      serviceAccountName: app-sa
```
```
kubectl apply -f needs-api.yaml
kubectl rollout status deploy/no-api deploy/needs-api -n sa-lab
```
Alternative: `kubectl set serviceaccount deployment needs-api app-sa -n sa-lab`.

5. `kubectl exec -n sa-lab deploy/no-api -- ls /var/run/secrets/kubernetes.io/serviceaccount`
6. `kubectl exec -n sa-lab deploy/needs-api -- ls /var/run/secrets/kubernetes.io/serviceaccount`
7. ```yaml
apiVersion: v1
kind: Pod
metadata:
  name: override-pod
  namespace: sa-lab
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
```
```
kubectl apply -f override-pod.yaml
kubectl exec -n sa-lab override-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount
```
8. ```
kubectl get pods -n sa-lab -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken
kubectl get pod -n sa-lab -o json | jq -r '.items[] | .metadata.name + " " + (.spec.volumes // [] | map(select(.projected != null)) | length | tostring)'
```
(The second command counts projected token volumes; 0 means none injected.)

## Expected output
```
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```
for `no-api` and `override-pod`; for `needs-api`:
```
ca.crt
namespace
token
```
The `AUTOMOUNT` column is `<none>` for Deployment pods (unset in pod spec) and `false` for `override-pod`; the SA-level setting is applied by the admission controller, so the pod's own field stays unset but the projected volume is absent.

## Why it works
The ServiceAccount admission controller injects the projected token volume unless `automountServiceAccountToken` is false on either the pod (takes precedence) or its ServiceAccount.

## Common mistakes / exam gotchas
- Patching the SA and expecting running pods to change; they must be recreated (`kubectl rollout restart deployment ...`).
- Setting `automountServiceAccountToken: false` on the SA but forgetting a pod spec of `true` overrides it.
- Setting false on the SA used by an app that needs the API, breaking it; fix by pod-level `true` or a dedicated SA.
- Assuming a Secret token exists for each SA: not since v1.24. Use `kubectl create token app-sa` for a temporary token.
- Binding roles to `default` SA: every pod in the namespace inherits them.
- The directory absence is the reliable test; the SA field alone does not prove it.

## Cleanup
```
kubectl delete ns sa-lab
```
