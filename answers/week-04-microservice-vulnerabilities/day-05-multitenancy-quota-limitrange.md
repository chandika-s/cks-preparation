# Week 4 · Day 5 (Oct 16) — Isolation: multi-tenancy with quotas and limits — Answers
Task: [day-05-multitenancy-quota-limitrange](../../plan/week-04-microservice-vulnerabilities/day-05-multitenancy-quota-limitrange.md)

## Solution
1. Namespaces:
```
kubectl create ns tenant-a
kubectl create ns tenant-b
```
2. Quota:
```
kubectl create quota tenant-a-quota -n tenant-a \
  --hard=pods=3,requests.cpu=1,requests.memory=1Gi,limits.cpu=2,limits.memory=2Gi
```
Equivalent YAML:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-a-quota
  namespace: tenant-a
spec:
  hard:
    pods: "3"
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
```
3. LimitRange:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-a-limits
  namespace: tenant-a
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 128Mi
    defaultRequest:
      cpu: 100m
      memory: 64Mi
    max:
      cpu: 500m
      memory: 512Mi
```
Save both and `kubectl apply -f`.

4. Deployment:
```
kubectl create deploy web -n tenant-a --image=nginx:1.27 --replicas=5
kubectl get pods -n tenant-a
kubectl describe rs -n tenant-a | grep -A3 -i quota
kubectl get pod -n tenant-a -o jsonpath='{.items[0].spec.containers[0].resources}'
```
5. Bare pod (`hog.yaml`):
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hog
  namespace: tenant-a
spec:
  containers:
  - name: hog
    image: nginx:1.27
    resources:
      limits:
        cpu: "1"
```
```
kubectl apply -f hog.yaml
```
6. `kubectl create deploy web -n tenant-b --image=nginx:1.27 --replicas=5`
7. `kubectl describe quota tenant-a-quota -n tenant-a`

## Expected output
Step 4 event:
```
Error creating: pods "web-xxxxx-yyyy" is forbidden: exceeded quota: tenant-a-quota, requested: pods=1, used: pods=3, limited: pods=3
```
Resources injected: `{"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"100m","memory":"64Mi"}}`.

Step 5:
```
Error from server (Forbidden): error when creating "hog.yaml": pods "hog" is forbidden: maximum cpu usage per Container is 500m, but limit is 1
```
Step 7:
```
Resource         Used   Hard
limits.cpu       600m   2
limits.memory    384Mi  2Gi
pods             3      3
requests.cpu     300m   1
requests.memory  192Mi  1Gi
```

## Why it works
LimitRanger (admission) first injects defaults and validates min/max; ResourceQuota (admission, last) then checks aggregate usage against `hard`. The `hog` pod fails at LimitRanger. Because the quota tracks `requests`/`limits`, the defaulting is what lets unspecified pods in at all; without the LimitRange the `web` pods would be rejected with `must specify limits.cpu for: nginx`.

## Common mistakes / exam gotchas
- Expecting `kubectl create deploy` to error; it succeeds, the failure is in ReplicaSet events.
- Quota with cpu/memory but no LimitRange defaults: pods without resources are rejected.
- `default` in LimitRange = default *limit*; `defaultRequest` = default request. Default limit above `max` is rejected.
- Quota is per namespace, not per user; LimitRange is per namespace too and applies only to new objects.
- `ResourceQuota` and `LimitRange` do not isolate network or RBAC; combine them.
- Values are quantity strings in YAML (`"3"`, `"1"`) inside `spec.hard`.

## Cleanup
```
kubectl delete ns tenant-a tenant-b
rm -f hog.yaml
```
