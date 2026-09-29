# Week 4 · Day 8 (Oct 19) — Review & self-quiz — Answers
Task: [day-08-review-self-quiz](../../plan/week-04-microservice-vulnerabilities/day-08-review-self-quiz.md)

## Solution
1. PSA
```
kubectl create ns quiz-psa
kubectl label ns quiz-psa pod-security.kubernetes.io/enforce=restricted
kubectl run bad -n quiz-psa --image=busybox:1.36 -- sleep 3600
```
`good.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: good
  namespace: quiz-psa
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: good
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```
`kubectl apply -f good.yaml`

2. Encryption at rest (on the node via `docker exec -it cks-control-plane bash`):
```
mkdir -p /etc/kubernetes/enc
cat > /etc/kubernetes/enc/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc:
          keys:
            - name: qkey1
              secret: $(head -c 32 /dev/urandom | base64)
      - identity: {}
EOF
chmod 600 /etc/kubernetes/enc/enc.yaml
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
```
In `/etc/kubernetes/manifests/kube-apiserver.yaml` add `--encryption-provider-config=/etc/kubernetes/enc/enc.yaml` to `command`, a `volumeMounts` entry `{mountPath: /etc/kubernetes/enc, name: enc, readOnly: true}` and a `volumes` entry `{name: enc, hostPath: {path: /etc/kubernetes/enc, type: DirectoryOrCreate}}`. Wait for the API server, then:
```
kubectl create secret generic quiz-secret --from-literal=k=v1
kubectl -n kube-system exec etcd-cks-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/quiz-secret | hexdump -C | head
```
Prefix: `k8s:enc:aescbc:v1:qkey1:`. Check `kubectl get secret quiz-secret -o jsonpath='{.data.k}' | base64 -d` returns `v1`.

3. Tenancy:
```
kubectl create ns quiz-tenant
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: quota
  namespace: quiz-tenant
spec:
  hard:
    pods: "2"
    requests.cpu: 500m
    requests.memory: 512Mi
    limits.cpu: "1"
    limits.memory: 1Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: limits
  namespace: quiz-tenant
spec:
  limits:
  - type: Container
    default:
      cpu: 250m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 500m
      memory: 512Mi
EOF
kubectl run p1 -n quiz-tenant --image=nginx:1.27
kubectl run p2 -n quiz-tenant --image=nginx:1.27
kubectl run p3 -n quiz-tenant --image=nginx:1.27
```

4. RuntimeClass:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
---
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed
  namespace: default
spec:
  runtimeClassName: kata
  containers:
  - name: sandboxed
    image: nginx:1.27
```
It will not run on `kind-cks` because the node's containerd has no `kata` runtime registered (and no hardware virtualization/Kata install); it needs Kata installed plus a `runtimes.kata` entry with `runtime_type = "io.containerd.kata.v2"` in `/etc/containerd/config.toml` and a containerd restart.

5. Model answer: CNI-level encryption (Cilium/Calico WireGuard or IPsec) encrypts node-to-node pod traffic at L3, transparently for all protocols, with node-level identity and no per-service authorization. Mesh mTLS (Istio, Linkerd) uses sidecars to give each workload its own certificate and mutual authentication at L4/L7, enabling identity-based authorization, at the cost of proxy overhead and complexity, and only for meshed pods. Neither needs application code changes. Choose CNI encryption for blanket, low-overhead protection; choose a mesh for zero-trust, per-service policy. Istio enforces strict mTLS with a `PeerAuthentication` (`mtls.mode: STRICT`; `PERMISSIVE` for migration).

## Expected output
- Item 1: `Error from server (Forbidden): pods "bad" is forbidden: violates PodSecurity "restricted:latest": ...`; `good` `1/1 Running`.
- Item 2: hexdump containing `k8s:enc:aescbc:v1:qkey1:`.
- Item 3: `Error from server (Forbidden): pods "p3" is forbidden: exceeded quota: quota, requested: pods=1, used: pods=2, limited: pods=2`.
- Item 4: `runtimeclass.node.k8s.io/kata created`; pod `ContainerCreating` with `no runtime for "kata" is configured` in events.

## Why it works
Each item repeats the mechanism from Days 1–7: PSA label-driven admission, apiserver-side encryption with provider prefix, LimitRanger then ResourceQuota admission, RuntimeClass handler to containerd lookup, and the layer distinction in pod-to-pod encryption.

## Common mistakes / exam gotchas
- Item 2: wrong provider order, missing volume/mount, backup file left in the manifests directory, testing with an old Secret and concluding it is not encrypted.
- Item 3: hard values must be quoted strings for numeric quantities in YAML (`"2"`); forgetting that unspecified pod resources are filled from the LimitRange.
- Item 4: pod-level field is `runtimeClassName`; the RuntimeClass name and handler are distinct.
- Timing: create files with heredocs and `kubectl apply -f -` rather than opening an editor.

## Cleanup
```
kubectl delete ns quiz-psa quiz-tenant
kubectl delete pod sandboxed
kubectl delete runtimeclass kata
kubectl delete secret quiz-secret
rm -f good.yaml
```
Revert encryption per the Day 3 answer Cleanup if desired.
