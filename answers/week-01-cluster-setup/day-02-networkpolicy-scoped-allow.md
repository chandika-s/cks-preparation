# Week 1 · Day 2 (Sep 24) — NetworkPolicy: scoped allow rules — Answers
Task: [plan/week-01-cluster-setup/day-02-networkpolicy-scoped-allow.md](../../plan/week-01-cluster-setup/day-02-networkpolicy-scoped-allow.md)

## Solution
```bash
kubectl expose pod web --port 80 -n secure-app
kubectl get pods -n secure-app --show-labels
kubectl get pods -n kube-system -l k8s-app=kube-dns --show-labels
kubectl get ns kube-system --show-labels
mkdir -p ~/netpol
```
Labels from `kubectl run`: `web` has `run=web`, `client` has `run=client`. CoreDNS: `k8s-app=kube-dns`. Namespace: `kubernetes.io/metadata.name=kube-system`.

```yaml
# ~/netpol/allow-client-to-web.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-to-web
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      run: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: client
    ports:
    - protocol: TCP
      port: 80
```

```yaml
# ~/netpol/allow-client-egress-web.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client-egress-web
  namespace: secure-app
spec:
  podSelector:
    matchLabels:
      run: client
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          run: web
    ports:
    - protocol: TCP
      port: 80
```

```yaml
# ~/netpol/allow-dns-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: secure-app
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

```bash
kubectl apply -f ~/netpol/
kubectl exec -n secure-app client -- wget -qO- -T 3 http://web
kubectl exec -n secure-app client -- wget -qO- -T 3 http://web:8080
kubectl exec -n secure-app client -- nslookup web
kubectl exec -n secure-app client -- wget -qO- -T 3 http://example.com
```

## Expected output
```
networkpolicy.networking.k8s.io/allow-client-to-web created
...
<title>Welcome to nginx!</title>        # http://web
wget: download timed out                # http://web:8080
Name:   web.secure-app.svc.cluster.local  Address: 10.96.x.x
wget: bad address 'example.com' / download timed out   # not allowed out
```
(`example.com` fails at DNS or connect: CoreDNS may resolve it, but egress to the internet is denied so the connection times out.)

## Why it works
`default-deny-all` leaves an empty allow set; each new policy adds one permitted flow. The client-to-web flow needs both the client's egress rule and the web's ingress rule. DNS is allowed for all pods via `podSelector: {}`. Because `namespaceSelector` and `podSelector` sit in the same list element, they AND: only CoreDNS pods in `kube-system`.

## Common mistakes / exam gotchas
- Writing `- namespaceSelector:` and `- podSelector:` as two dashes makes an OR: every pod in `kube-system` plus every matching pod in the local namespace.
- Only creating the ingress policy: the client's egress is still denied, so the flow fails.
- Forgetting TCP 53; large DNS responses fall back to TCP.
- Selecting the kube-dns Service ClusterIP with `ipBlock` instead of pods: fragile; use pod selectors.
- A timeout means dropped by policy; "connection refused" means the packet arrived but nothing listens.
- Label typos silently match nothing; confirm with `kubectl get pods -l ... --show-labels`.

## Cleanup
Keep the namespace until Day 7 if you want to reuse it; otherwise `kubectl delete ns secure-app`.
