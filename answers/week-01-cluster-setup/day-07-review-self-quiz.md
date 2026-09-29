# Week 1 · Day 7 (Sep 29) — Review & self-quiz — Answers
Task: [plan/week-01-cluster-setup/day-07-review-self-quiz.md](../../plan/week-01-cluster-setup/day-07-review-self-quiz.md)

## Solution
1. Default deny:
```bash
kubectl create ns quiz1
kubectl run a --image=nginx -n quiz1
kubectl run b --image=nginx -n quiz1
```
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: quiz1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```
```bash
B_IP=$(kubectl get pod b -n quiz1 -o jsonpath='{.status.podIP}')
kubectl exec -n quiz1 a -- curl -s -m 3 http://$B_IP
```
(The nginx image includes `curl`.)

2. Scoped allow:
```bash
kubectl create ns quiz2
kubectl run web --image=nginx -l app=web -n quiz2
kubectl run client --image=busybox -l app=client -n quiz2 -- sleep 3600
kubectl expose pod web --port 80 -n quiz2
```
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: quiz2
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-ingress
  namespace: quiz2
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: client-egress
  namespace: quiz2
spec:
  podSelector:
    matchLabels:
      app: client
  policyTypes: [Egress]
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: quiz2
spec:
  podSelector: {}
  policyTypes: [Egress]
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
Verify: `kubectl exec -n quiz2 client -- wget -qO- -T 3 http://web`, `... http://web:8080` (times out), `... nslookup web`.

3. Model answer (kube-bench):
- kube-bench runs the CIS Kubernetes Benchmark checks: control-plane files and component flags, etcd, kubelet/worker config, and policy items (RBAC, PSA, NetworkPolicy, secrets).
- Runs as a Job (or binary) on the node with host mounts; output lines are `[PASS]`, `[FAIL]`, `[WARN]` (manual), `[INFO]`, with a Remediations section and summary counts.
- For `1.2.1 --anonymous-auth=false`: on the control-plane node edit `/etc/kubernetes/manifests/kube-apiserver.yaml`, add `- --anonymous-auth=false` to `spec.containers[0].command`, save; the kubelet recreates the static pod. Wait for `kubectl get pods -n kube-system` and `/readyz`.
- Keep a backup outside the manifests dir; if the apiserver does not come back, restore and check `crictl logs` and `journalctl -u kubelet`.
- Risk: kubeadm probes hit `/livez`/`/readyz` unauthenticated, so disabling anonymous auth can cause probe failures; newer versions can restrict anonymous access to health endpoints via structured authentication configuration. Also kubelet: `authentication.anonymous.enabled: false` in the kubelet config.

4. TLS ingress:
```bash
kubectl create ns quiz4
kubectl create deployment app --image=nginx --replicas=2 -n quiz4
kubectl expose deployment app --port 80 -n quiz4
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/quiz.key -out /tmp/quiz.crt \
  -subj "/CN=quiz.example.com" -addext "subjectAltName=DNS:quiz.example.com"
kubectl create secret tls quiz-tls --cert=/tmp/quiz.crt --key=/tmp/quiz.key -n quiz4
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-tls
  namespace: quiz4
spec:
  ingressClassName: nginx
  tls:
  - hosts: [quiz.example.com]
    secretName: quiz-tls
  rules:
  - host: quiz.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app
            port:
              number: 80
```
```bash
curl -vk --resolve quiz.example.com:443:127.0.0.1 https://quiz.example.com 2>&1 | grep -E 'subject|Welcome'
```

5. Metadata block:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-imds
  namespace: quiz5
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: [169.254.169.254/32]
```
(Create `quiz5` first.) Kubelet settings: `authentication.anonymous.enabled: false` and `authorization.mode: Webhook` (also `readOnlyPort: 0`).

## Expected output
Items 1-2: timeouts for blocked flows, nginx HTML for allowed flows. Item 4: `subject: CN=quiz.example.com` and `Welcome to nginx!`. Item 5: `kubectl get netpol -n quiz5` lists `block-imds`.

## Why it works
Same mechanics as Days 1-5: additive allow-only policies enforced by Calico; TLS Secret consumed by ingress-nginx; ipBlock exception for one address; kubelet authn/authz gates the 10250 API.

## Common mistakes / exam gotchas
- Missing `policyTypes` or forgetting one direction.
- OR vs AND selector indentation.
- Forgetting DNS egress and the destination's ingress rule.
- TLS Secret in the wrong namespace; missing `ingressClassName`.
- Budgeting: if a task takes over 10 minutes on the exam, flag it and move on.
- Not using `kubectl explain` / docs snippets; copy the docs example and edit.

## Cleanup
```bash
kubectl delete ns quiz1 quiz2 quiz4 quiz5
rm -f /tmp/quiz.key /tmp/quiz.crt
```
