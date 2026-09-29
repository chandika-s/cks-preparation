# Week 1 · Day 4 (Sep 26) — Ingress with TLS — Answers
Task: [plan/week-01-cluster-setup/day-04-ingress-tls.md](../../plan/week-01-cluster-setup/day-04-ingress-tls.md)

## Solution
1. Controller:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s
```
2-4. Namespace, cert, secret:
```bash
kubectl create ns tls-lab
mkdir -p ~/tls && cd ~/tls
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=cks.example.com" -addext "subjectAltName=DNS:cks.example.com"
kubectl create secret tls cks-tls --cert=tls.crt --key=tls.key -n tls-lab
```
5. Workload:
```bash
kubectl create deployment web --image=nginx --replicas=2 -n tls-lab
kubectl expose deployment web --port=80 -n tls-lab
```
6. Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-tls
  namespace: tls-lab
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - cks.example.com
    secretName: cks-tls
  rules:
  - host: cks.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```
```bash
kubectl apply -f ~/tls/ingress.yaml
```
`kubectl create deployment` sets label `app=web`, which the Service selects.

7. Verify:
```bash
curl -k --resolve cks.example.com:443:127.0.0.1 https://cks.example.com
curl -vk --resolve cks.example.com:443:127.0.0.1 https://cks.example.com 2>&1 | grep -E 'subject|issuer'
curl -sI --resolve cks.example.com:80:127.0.0.1 http://cks.example.com
```

## Expected output
```
<title>Welcome to nginx!</title>
*  subject: CN=cks.example.com
*  issuer: CN=cks.example.com
HTTP/1.1 308 Permanent Redirect
Location: https://cks.example.com
```

## Why it works
Kind maps host 80/443 to the control-plane node, where the controller binds hostPorts (the node is labelled `ingress-ready=true` and the controller tolerates the control-plane taint). `--resolve` fakes DNS for the Host/SNI. The controller reads the Secret referenced by `spec.tls` and uses it for SNI `cks.example.com`; ingress-nginx redirects HTTP to HTTPS when TLS is configured for the host.

## Common mistakes / exam gotchas
- Applying the Ingress before the admission webhook is ready gives `failed calling webhook ... connection refused`; wait for the controller and retry.
- Secret in a different namespace than the Ingress: the controller falls back to the fake default certificate.
- Missing `ingressClassName` on a cluster with no default IngressClass: the Ingress is ignored.
- `hosts` in `tls` not matching the rule host or cert SAN.
- Wrong secret type (`generic` with the same keys) or `tls.crt`/`tls.key` swapped.
- `curl` without `-k` fails on a self-signed cert; use `--cacert tls.crt` to verify properly.
- If ports 80/443 are not mapped on your cluster, use the mapped ports from `SETUP.md` (`--resolve host:<port>:127.0.0.1`).

## Cleanup
```bash
kubectl delete ns tls-lab
```
