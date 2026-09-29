# Week 7 · Day 4 (Nov 8) — Mixed set: Ingress/TLS + seccomp/AppArmor + Kyverno
**Domain:** Cluster Setup (15%) + System Hardening (10%) + Supply Chain Security (20%) + Cluster Hardening (15%) | **Est. time:** 90 min | **Cluster:** kind-cks

## Objectives
- Publish a service over TLS with an Ingress and prove the certificate and redirect behaviour.
- Author and apply a custom seccomp profile, and describe the AppArmor equivalent.
- Write a Kyverno ClusterPolicy that restricts registries and image tags, scoped by namespace label.
- Inspect API server exposure settings.

## Theory
**Ingress TLS.** `spec.tls[].hosts` + `secretName` referencing a `kubernetes.io/tls` Secret (keys `tls.crt`, `tls.key`) in the same namespace as the Ingress. `spec.ingressClassName` selects the controller. `kubectl create secret tls <name> --cert=... --key=...`. Self-signed cert: `openssl req -x509 -nodes -newkey rsa:2048 -days N -keyout tls.key -out tls.crt -subj "/CN=host" -addext "subjectAltName=DNS:host"`. ingress-nginx redirects HTTP to HTTPS by default when TLS is configured (annotation `nginx.ingress.kubernetes.io/ssl-redirect`). Without a valid secret the controller serves its default self-signed "Kubernetes Ingress Controller Fake Certificate". Test with `curl -k --resolve host:port:127.0.0.1 https://host:port/` and `openssl s_client -servername host`.

**seccomp.** Profile JSON: `defaultAction` (`SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO`, `SCMP_ACT_LOG`, `SCMP_ACT_KILL...`) plus `syscalls: [{names: [...], action: ...}]`. Localhost profiles must exist on the node under the kubelet seccomp dir (`/var/lib/kubelet/seccomp/`; the `localhostProfile` path is relative to it). Pod field: `securityContext.seccompProfile: {type: Localhost, localhostProfile: profiles/x.json}`; types `RuntimeDefault`, `Unconfined`, `Localhost`. Profile must be present on the node where the pod is scheduled, otherwise the pod fails with `CreateContainerError`. Syscall names are architecture-specific (arm64 has no `mkdir`, only `mkdirat`).

**AppArmor.** Profile loaded on the node (`apparmor_parser -r`, check with `aa-status`); Pod field (v1.30+) `securityContext.appArmorProfile: {type: Localhost, localhostProfile: <name>}` at pod or container level; types `RuntimeDefault`, `Localhost`, `Unconfined`. Older form is annotation `container.apparmor.security.beta.kubernetes.io/<container>: localhost/<name>`. Not available on kind under Docker Desktop for macOS (the Linux VM kernel lacks the AppArmor LSM), so this is written and reasoned, not run.

**Kyverno.** `ClusterPolicy` with `spec.validationFailureAction: Enforce|Audit` (newer versions also accept `validate.failureAction`), `rules[].match.any[].resources` (`kinds`, `namespaces`, `namespaceSelector`, `selector`), `exclude`, and `validate.pattern` / `anyPattern` / `deny`. Pattern operators: `*` and `?` wildcards, `|` OR, `!` negation, `=()` conditional anchor (apply only if the key exists). Pod rules auto-generate rules for controllers. Test with `kubectl run ... --dry-run=server` and inspect `kubectl get cpol`.

**API exposure.** `kube-apiserver` flags to know: `--anonymous-auth`, `--authorization-mode=Node,RBAC`, `--enable-admission-plugins=NodeRestriction`, `--profiling`, `--insecure-port` (removed). Anonymous requests are authenticated as `system:anonymous` / group `system:unauthenticated`; RBAC then decides (kubeadm binds `system:public-info-viewer` for `/version`, `/healthz`, `/livez`, `/readyz`).

## Prerequisites
- ingress-nginx installed (Week 1 Day 4) in namespace `ingress-nginx`, IngressClass `nginx`.
- Kyverno installed (Week 5 Day 5) and Ready in namespace `kyverno`.
- `openssl`, `curl`, `jq` on the host.

## Task
Total 90 min / 100 points.

### Task 1 — TLS Ingress (20 min, 25 pts)
1. Create namespace `store`, Deployment `catalog` (`nginx:1.27`, 2 replicas) and ClusterIP Service `catalog-svc` (port 80).
2. Generate a self-signed certificate valid 30 days for CN `catalog.mock.local` (with matching SAN) and store it as TLS Secret `catalog-tls` in `store`.
3. Create Ingress `catalog-ing` (class `nginx`, host `catalog.mock.local`, path `/` Prefix to `catalog-svc:80`) terminating TLS with `catalog-tls`; HTTP must redirect to HTTPS.
4. Without editing `/etc/hosts`, prove: (a) HTTPS returns 200 through the controller, (b) the served certificate subject is `CN=catalog.mock.local`, (c) plain HTTP returns a 308 redirect. Save these three results to `/tmp/ingress-proof.txt`.

### Task 2 — Custom seccomp profile (20 min, 25 pts)
1. Write `/tmp/block-mkdir.json`: default action allow; return `EPERM` (`SCMP_ACT_ERRNO`) for the syscalls `mkdir` and `mkdirat`.
2. Install it on node `cks-worker` so a pod can reference it as `profiles/block-mkdir.json`.
3. In namespace `sandbox`, create Pod `no-mkdir` (`busybox:1.36`, `sleep 3600`) scheduled on `cks-worker` using this profile (via the pod securityContext), and Pod `with-mkdir` (same image and node) using `RuntimeDefault`.
4. Prove `mkdir /tmp/x` fails in `no-mkdir` with "Operation not permitted" and succeeds in `with-mkdir`.

### Task 3 — AppArmor (paper task, 5 min, 5 pts)
Write `/tmp/apparmor-notes.md` containing: the Pod `securityContext` snippet that would apply a node-loaded AppArmor profile named `k8s-deny-write` to a container; the node-side commands to load and verify it; and one sentence on why you cannot run it on this cluster.

### Task 4 — Kyverno registry restriction (20 min, 25 pts)
1. Create namespaces `secure` (label `registry-policy=enforced`) and `open` (no label).
2. Create ClusterPolicy `restrict-registries`, `Enforce` mode, applying only to Pods in namespaces labelled `registry-policy=enforced`, with rules:
   - `allowed-registries`: every container and (if present) init container image must start with `registry.k8s.io/` or `ghcr.io/mock-org/`.
   - `require-tag`: images must have an explicit tag.
   - `no-latest`: the tag `latest` is forbidden.
3. Demonstrate: in `secure`, `nginx:1.27` is denied (registry), `registry.k8s.io/pause:3.9` is admitted, `registry.k8s.io/pause:latest` is denied; in `open`, `nginx:1.27` is admitted. Save the three `secure` command outputs to `/tmp/kyverno-proof.txt`.

### Task 5 — API server exposure check (15 min, 20 pts)
1. Save the values of `--authorization-mode`, `--enable-admission-plugins` and `--anonymous-auth` (or a note that it is unset and therefore defaults to true) from the API server manifest to `/tmp/apiserver-check.txt`.
2. From the host, without credentials, request `<server>/version` and `<server>/api` and append the HTTP status codes to the same file.
3. Write to `/tmp/anon-bindings.txt` the names of all ClusterRoleBindings that have `system:anonymous` or `system:unauthenticated` as a subject.
4. Answer in the file: why is setting `--anonymous-auth=false` on a kubeadm/kind control plane risky without additional changes?

## Check your work
- Task 1: proof file shows `200`, `subject=CN=catalog.mock.local` (or equivalent) and `HTTP/1.1 308` with `Location: https://catalog.mock.local...`.
- Task 2: `no-mkdir` Running; mkdir output "Operation not permitted"; the profile is present on the worker only.
- Task 3: notes file contains `appArmorProfile: type: Localhost` snippet and `apparmor_parser` / `aa-status` commands.
- Task 4: denials cite `restrict-registries`/rule name; `open` pod Running; `kubectl get cpol restrict-registries` READY true.
- Task 5: `/api` returns 403 (anonymous forbidden), `/version` returns 200; binding list includes `system:public-info-viewer`.

## Answer
[answers/week-07-mock-exams/day-04-ingress-seccomp-kyverno.md](../../answers/week-07-mock-exams/day-04-ingress-seccomp-kyverno.md) — Attempt the task first; only then open the answer.

## Cleanup
```
kubectl delete ns store sandbox secure open
kubectl delete cpol restrict-registries
docker exec cks-worker rm -f /var/lib/kubelet/seccomp/profiles/block-mkdir.json
```
Stop any leftover `kubectl port-forward` processes.
