# Week 7 · Day 4 (Nov 8) — Mixed set: Ingress/TLS + seccomp/AppArmor + Kyverno — Answers
Task: [plan/week-07-mock-exams/day-04-ingress-seccomp-kyverno.md](../../plan/week-07-mock-exams/day-04-ingress-seccomp-kyverno.md)

## Solution

### Task 1 — TLS Ingress
```
kubectl create ns store
kubectl -n store create deploy catalog --image=nginx:1.27 --replicas=2
kubectl -n store expose deploy catalog --name=catalog-svc --port=80
cd /tmp
openssl req -x509 -nodes -newkey rsa:2048 -days 30 -keyout tls.key -out tls.crt \
  -subj "/CN=catalog.mock.local" -addext "subjectAltName=DNS:catalog.mock.local"
kubectl -n store create secret tls catalog-tls --cert=tls.crt --key=tls.key
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: catalog-ing
  namespace: store
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - catalog.mock.local
    secretName: catalog-tls
  rules:
  - host: catalog.mock.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: catalog-svc
            port:
              number: 80
```
Proof (port-forward the controller; adjust the Service name/ports if your Week 1 install exposes 80/443 on host ports through kind `extraPortMappings`, in which case use those directly):
```
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8443:443 8080:80 &
sleep 2
{
curl -sk -o /dev/null -w 'https=%{http_code}\n' --resolve catalog.mock.local:8443:127.0.0.1 https://catalog.mock.local:8443/
openssl s_client -connect 127.0.0.1:8443 -servername catalog.mock.local </dev/null 2>/dev/null | openssl x509 -noout -subject
curl -si --resolve catalog.mock.local:8080:127.0.0.1 http://catalog.mock.local:8080/ | head -5
} | tee /tmp/ingress-proof.txt
kill %1
```

### Task 2 — seccomp
```
cat > /tmp/block-mkdir.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
docker exec cks-worker mkdir -p /var/lib/kubelet/seccomp/profiles
docker cp /tmp/block-mkdir.json cks-worker:/var/lib/kubelet/seccomp/profiles/block-mkdir.json
kubectl create ns sandbox
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-mkdir
  namespace: sandbox
spec:
  nodeName: cks-worker
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/block-mkdir.json
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: with-mkdir
  namespace: sandbox
spec:
  nodeName: cks-worker
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "3600"]
```
```
kubectl -n sandbox exec no-mkdir -- mkdir /tmp/x
kubectl -n sandbox exec with-mkdir -- mkdir /tmp/x && echo ok
```
The `mkdir` name is absent on arm64 (Apple silicon); the runtime skips names unknown to the architecture, and `mkdirat` covers busybox. If the pod sits in `CreateContainerError`, the profile path is wrong or on the wrong node: `kubectl -n sandbox describe pod no-mkdir`.

### Task 3 — AppArmor (paper)
`/tmp/apparmor-notes.md`:
```
Pod/container securityContext (v1.30+):
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-deny-write

Node side (on every node where the pod may run):
  apparmor_parser -q -r /etc/apparmor.d/k8s-deny-write
  aa-status | grep k8s-deny-write

Profile example:
  #include <tunables/global>
  profile k8s-deny-write flags=(attach_disconnected) {
    #include <abstractions/base>
    file,
    deny /** w,
  }

Legacy annotation: container.apparmor.security.beta.kubernetes.io/<container>: localhost/k8s-deny-write

Not runnable on kind under Docker Desktop for macOS: the Linux VM kernel has no AppArmor LSM, so profiles cannot be loaded and pods requesting Localhost profiles fail to start.
```

### Task 4 — Kyverno
```
kubectl create ns secure
kubectl label ns secure registry-policy=enforced
kubectl create ns open
```
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-registries
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: allowed-registries
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaceSelector:
            matchLabels:
              registry-policy: enforced
    validate:
      message: "Images must come from registry.k8s.io/ or ghcr.io/mock-org/."
      pattern:
        spec:
          =(initContainers):
          - image: "registry.k8s.io/* | ghcr.io/mock-org/*"
          containers:
          - image: "registry.k8s.io/* | ghcr.io/mock-org/*"
  - name: require-tag
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaceSelector:
            matchLabels:
              registry-policy: enforced
    validate:
      message: "An explicit image tag is required."
      pattern:
        spec:
          containers:
          - image: "*:*"
  - name: no-latest
    match:
      any:
      - resources:
          kinds: ["Pod"]
          namespaceSelector:
            matchLabels:
              registry-policy: enforced
    validate:
      message: "The latest tag is not allowed."
      pattern:
        spec:
          containers:
          - image: "!*:latest"
```
Test:
```
{
kubectl -n secure run bad --image=nginx:1.27
kubectl -n secure run good --image=registry.k8s.io/pause:3.9
kubectl -n secure run lat --image=registry.k8s.io/pause:latest
} 2>&1 | tee /tmp/kyverno-proof.txt
kubectl -n open run any --image=nginx:1.27
kubectl get cpol restrict-registries
```
Kyverno version note: newer releases prefer `validate.failureAction: Enforce` per rule; `spec.validationFailureAction` still works but is deprecated. If the server rejects your field, use the per-rule form.

### Task 5 — API server exposure
```
docker exec cks-control-plane grep -E -- '--(authorization-mode|enable-admission-plugins|anonymous-auth)' /etc/kubernetes/manifests/kube-apiserver.yaml | tee /tmp/apiserver-check.txt
echo "anonymous-auth: unset means default true" >> /tmp/apiserver-check.txt
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
for p in /version /api; do curl -sk -o /dev/null -w "$p %{http_code}\n" $SERVER$p; done | tee -a /tmp/apiserver-check.txt
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(any(.subjects[]?; .name=="system:unauthenticated" or .name=="system:anonymous")) | .metadata.name' > /tmp/anon-bindings.txt
echo "--anonymous-auth=false breaks kubeadm-style apiserver liveness/readiness probes (httpGet to /livez, /readyz are unauthenticated) and kubeadm health checks, causing restart loops, unless probes/anonymous-endpoint config are changed." >> /tmp/apiserver-check.txt
```
Do not actually flip `--anonymous-auth=false` on this cluster.

## Expected output
- Task 1: `https=200`, `subject=CN=catalog.mock.local`, HTTP response `HTTP/1.1 308 Permanent Redirect`, `Location: https://catalog.mock.local/`.
- Task 2: `mkdir: can't create directory '/tmp/x': Operation not permitted` for `no-mkdir`.
- Task 4: `Error from server: admission webhook "validate.kyverno.svc-fail" denied the request: resource Pod/secure/bad was blocked due to the following policies restrict-registries: allowed-registries: validation error: Images must come from ...`.
- Task 5: `/version 200`, `/api 403`, binding list `system:public-info-viewer`.

## Why it works
- The ingress controller picks the certificate by SNI/host from the Secret named in `spec.tls`.
- The kubelet passes `localhostProfile` (relative to its seccomp dir) to the runtime, which installs the BPF filter for the container.
- Kyverno pattern matching evaluates each container image string against the wildcard/OR expression; `namespaceSelector` scopes the rule.

## Common mistakes / exam gotchas
- TLS Secret in a different namespace from the Ingress; `hosts` not matching `rules[].host`.
- Forgetting `ingressClassName` (ingress ignored).
- CN only, no SAN: modern clients reject it.
- Seccomp path: `localhostProfile` must be relative (`profiles/x.json`), not absolute; profile on the wrong node; pod not pinned to a node that has it.
- Confusing pod-level `seccompProfile` with the deprecated `seccomp.security.alpha.kubernetes.io/pod` annotation.
- Kyverno pattern: image `nginx` (no registry) does not match `docker.io/*`; the string is matched as written. Also policies with no namespace scoping can block system pods on restart.
- Writing YAML `image: "!*:latest"` unquoted (parse error on `!`/`*`).
- Kyverno webhook down means denies or fail-open depending on `failurePolicy`.

## Cleanup
```
kubectl delete ns store sandbox secure open
kubectl delete cpol restrict-registries
docker exec cks-worker rm -f /var/lib/kubelet/seccomp/profiles/block-mkdir.json
```
