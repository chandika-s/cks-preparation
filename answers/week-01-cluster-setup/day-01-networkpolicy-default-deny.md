# Week 1 · Day 1 (Sep 23) — NetworkPolicy: default-deny — Answers
Task: [plan/week-01-cluster-setup/day-01-networkpolicy-default-deny.md](../../plan/week-01-cluster-setup/day-01-networkpolicy-default-deny.md)

## Solution
```bash
kubectl create ns secure-app
kubectl run web --image=nginx -n secure-app
kubectl run client --image=busybox -n secure-app -- sleep 3600
kubectl wait --for=condition=Ready pod/web pod/client -n secure-app --timeout=120s

WEB_IP=$(kubectl get pod web -n secure-app -o jsonpath='{.status.podIP}')
kubectl exec -n secure-app client -- wget -qO- -T 3 http://$WEB_IP
kubectl exec -n secure-app client -- nslookup kubernetes.default
```

```yaml
# ~/default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: secure-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

```bash
kubectl apply -f ~/default-deny-all.yaml
kubectl exec -n secure-app client -- wget -qO- -T 3 http://$WEB_IP
kubectl exec -n secure-app client -- nslookup -timeout=3 kubernetes.default
```

## Expected output
```
# before
<!DOCTYPE html> ... <title>Welcome to nginx!</title> ...
Name:   kubernetes.default ... Address: 10.96.0.1
# after
wget: download timed out
;; connection timed out; no servers could be reached
command terminated with exit code 1
```
`kubectl describe netpol default-deny-all -n secure-app` shows `Spec: PodSelector: <none> (Allowing the specific traffic to all pods in this namespace)`, `Not affecting egress/ingress` absent, `Policy Types: Ingress, Egress`.

## Why it works
The policy selects every pod (`podSelector: {}`) for both directions and defines no rules, so Calico's allow set is empty and drops all traffic. Egress from `client` is dropped (blocking the request and DNS to CoreDNS); ingress to `web` would also be dropped independently.

## Common mistakes / exam gotchas
- Omitting `policyTypes: [Egress]` yields an ingress-only policy; egress stays open.
- Writing `ingress: [{}]` or `egress: [{}]` allows everything; an empty policy is deny, an empty rule is allow-all.
- `podSelector: {}` is all pods; `podSelector` missing entirely is invalid.
- Testing on a non-enforcing CNI silently passes; confirm the traffic actually breaks.
- busybox has no `curl`; use `wget`.
- Always pass `-n <namespace>`; the policy is namespaced.

## Cleanup
Keep `secure-app` and its pods for Day 2.
