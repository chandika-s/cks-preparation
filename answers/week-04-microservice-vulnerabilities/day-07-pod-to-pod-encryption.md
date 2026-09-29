# Week 4 · Day 7 (Oct 18) — Pod-to-Pod encryption (Cilium/Istio mTLS) — Answers
Task: [day-07-pod-to-pod-encryption](../../plan/week-04-microservice-vulnerabilities/day-07-pod-to-pod-encryption.md)

## Solution
Part A (optional). Honest caveat: WireGuard needs kernel support inside the kind node's kernel (Docker Desktop's Linux VM on macOS). It may or may not be present; if the agent reports a WireGuard error, do Part B and stop.

1. `cilium-kind.yaml`:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
```
```
kind create cluster --name cks-cilium --config cilium-kind.yaml
```
2. Install:
```
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --namespace kube-system \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
kubectl --context kind-cks-cilium -n kube-system rollout status ds/cilium
```
(Nodes stay `NotReady` until Cilium is up. Some kind setups also need `--set kubeProxyReplacement=false` or image preloading; adapt to the Cilium docs for kind.)
3. Verify:
```
kubectl --context kind-cks-cilium -n kube-system exec ds/cilium -- cilium-dbg encrypt status
```
(Older Cilium releases name the binary `cilium` instead of `cilium-dbg`.)
4. `kubectl config use-context kind-cks`

Part B. Model answer:

CNI-level encryption (Cilium WireGuard/IPsec, Calico WireGuard) works at L3 between nodes: the CNI wraps all inter-node pod traffic in a tunnel, identity is the node's key, and it needs no sidecars or application changes, covering any protocol, meshed or not. Service-mesh mTLS (Istio, Linkerd) works at L4/L7 through proxies: each workload gets a SPIFFE-style certificate tied to its ServiceAccount, both peers authenticate, and traffic is encrypted end to end between proxies; it also enables identity-based authorization (`AuthorizationPolicy`) and L7 telemetry, again without app code changes. Choose CNI encryption for cheap, blanket protection of all cluster traffic (e.g. compliance requires encryption in transit and workloads are mixed TCP/UDP/legacy). Choose a mesh when you need per-service identity and zero-trust policy (e.g. only `frontend` may call `payments`). In Istio, `PeerAuthentication` with `mtls.mode: STRICT` enforces mTLS; `PERMISSIVE` is the migration mode that accepts plaintext and mTLS. Limitations of CNI encryption: no workload identity or authorization, same-node traffic and the node itself are outside the tunnel, needs kernel/feature support. Limitations of a mesh: sidecar CPU/memory/latency and operational complexity, only meshed (injected) workloads and supported protocols are covered, and misconfigured PERMISSIVE silently leaves plaintext.

Istio strict example (not required to run):
```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

Part C:
```
kubectl --context kind-cks get pods -A | grep -i -e calico -e cilium
kubectl --context kind-cks get felixconfiguration default -o yaml 2>/dev/null | grep -i wireguard
```
Calico is the CNI; it does not encrypt by default. Setting `wireguardEnabled: true` in `FelixConfiguration` (`calicoctl patch felixconfiguration default --type=merge -p '{"spec":{"wireguardEnabled":true}}'`) enables WireGuard where the kernel supports it. (The `felixconfiguration` CRD lookup requires the Calico CRDs, present with a standard install.)

## Expected output
Cilium status (abbreviated):
```
Encryption: Wireguard   [cilium_wg0 (Pubkey ..., Port: 51871, Peers: 1)]
```
Part C lists `calico-node-*` and `calico-kube-controllers-*`; the felix grep prints nothing or `wireguardEnabled: false`.

## Why it works
The CNI encryption is transparent to pods: the datapath encrypts before the packet leaves the node. The mesh terminates and originates TLS in the sidecar, so the app speaks plaintext to localhost.

## Common mistakes / exam gotchas
- Claiming mesh mTLS needs application changes or that CNI encryption authenticates workloads.
- Believing `PERMISSIVE` is secure; it is only for migration.
- Forgetting `disableDefaultCNI: true` in the kind config (kindnet conflicts with Cilium) and that nodes are NotReady until the CNI installs.
- Kubernetes NetworkPolicy does not encrypt; it only filters.
- Mesh encryption applies only to pods with sidecars/ambient enrolment.

## Cleanup
```
kind delete cluster --name cks-cilium
kubectl config use-context kind-cks
rm -f cilium-kind.yaml
```
