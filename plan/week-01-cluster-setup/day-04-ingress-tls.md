# Week 1 · Day 4 (Sep 26) — Ingress with TLS
**Domain:** Cluster Setup (15%) — Ingress with TLS | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Install an ingress controller on kind.
- Create a self-signed certificate and a `kubernetes.io/tls` Secret.
- Publish a Service over HTTPS through an Ingress with TLS termination.
- Verify the certificate served and the routing.

## Theory
- An `Ingress` object does nothing without an ingress controller (ingress-nginx here). The controller watches Ingress objects that match its `IngressClass`; use `spec.ingressClassName: nginx`.
- TLS: `spec.tls[]` entries have `hosts` and `secretName`. The Secret must be type `kubernetes.io/tls` with keys `tls.crt` and `tls.key`, in the same namespace as the Ingress. The certificate CN/SAN should match the host; otherwise the controller serves its default fake certificate.
- Create the Secret with `kubectl create secret tls <name> --cert=... --key=...`.
- Routing: `spec.rules[].host` and `http.paths[]` with `path`, `pathType` (`Prefix` or `Exact`) and `backend.service.{name,port.number}`.
- Self-signed cert: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=host"`. Modern clients want a SAN; add `-addext "subjectAltName=DNS:host"` (OpenSSL 1.1.1+).
- On kind the control-plane node carries label `ingress-ready=true` and host ports 80/443 are mapped (see `SETUP.md`); the kind provider manifest runs the controller with hostPort on that node.
- Useful commands: `kubectl get ingress`, `kubectl describe ingress`, `kubectl get ingressclass`, `kubectl -n ingress-nginx get pods`, `curl -v`, `openssl x509 -in tls.crt -noout -subject -dates`.
- CKS relevance: enforce HTTPS, avoid plaintext, control certificate handling.

## Prerequisites
`SETUP.md` port mappings for 80/443 in place on the kind cluster (`kind-cks.yaml`). Internet access to fetch the manifest and images. `openssl` and `curl` on the host.

## Task
1. Install the kind-specific ingress-nginx manifest (`kubernetes/ingress-nginx`, `main` branch, `deploy/static/provider/kind/deploy.yaml`). Wait until the controller pod in namespace `ingress-nginx` is Ready.
2. Create namespace `tls-lab`.
3. Generate a self-signed certificate valid 365 days for `cks.example.com` (CN and SAN) into `~/tls/tls.crt` and `~/tls/tls.key`.
4. Create a TLS Secret `cks-tls` in `tls-lab` from those files.
5. In `tls-lab` create Deployment `web` (image `nginx`, 2 replicas, label `app=web`) and a ClusterIP Service `web` on port 80.
6. Create Ingress `web-tls` in `tls-lab`: class `nginx`, host `cks.example.com`, TLS with secret `cks-tls` for that host, path `/` (Prefix) routed to Service `web` port 80.
7. Verify HTTPS from your host without editing `/etc/hosts`, then verify the served certificate is yours, and that plain HTTP redirects to HTTPS.

## Check your work
- `kubectl get pods -n ingress-nginx` shows the controller `Running` and `1/1`.
- `kubectl get secret cks-tls -n tls-lab -o jsonpath='{.type}'` prints `kubernetes.io/tls`.
- `kubectl get ingress -n tls-lab` shows class `nginx`, host `cks.example.com`, ports `80, 443`.
- `curl -k --resolve cks.example.com:443:127.0.0.1 https://cks.example.com` returns the nginx welcome page.
- `curl -vk --resolve ...` output shows `subject: CN=cks.example.com` (not "Kubernetes Ingress Controller Fake Certificate").
- `curl -sI --resolve cks.example.com:80:127.0.0.1 http://cks.example.com` returns a `308` redirect to https.

## Answer
[answers/week-01-cluster-setup/day-04-ingress-tls.md](../../answers/week-01-cluster-setup/day-04-ingress-tls.md) — Attempt the task first; only then open the answer.

## Cleanup
Optional: `kubectl delete ns tls-lab`. Leave ingress-nginx installed; Day 7 reuses it.
