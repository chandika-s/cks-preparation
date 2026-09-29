# Week 4 · Day 7 (Oct 18) — Pod-to-Pod encryption (Cilium/Istio mTLS)
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks (optional second kind cluster `cks-cilium`)

## Objectives
- Distinguish CNI-level transparent encryption from service-mesh mTLS.
- Know how each is enabled and what it does and does not protect.
- Optionally stand up Cilium with WireGuard encryption on a separate kind cluster.

## Theory
By default pod traffic is plaintext on the node network. Two families of solution:

CNI / network layer (L3, node-to-node tunnels):
- Cilium transparent encryption: WireGuard (`encryption.enabled=true`, `encryption.type=wireguard`) or IPsec (needs a key Secret). Encrypts pod-to-pod traffic between nodes, no app or sidecar changes, all protocols. Identity is per node, not per workload; no per-service authorization from the encryption itself. Traffic within the same node is not encrypted over the wire.
- Calico also supports WireGuard (`wireguardEnabled: true` in FelixConfiguration); the `kind-cks` Calico install could do this in principle, but needs the WireGuard kernel module on the node.
- Kernel/OS prerequisite: WireGuard support in the node kernel (Linux 5.6+ built in).

Service-mesh layer (L4/L7, per-workload identity):
- Istio / Linkerd sidecars (or ambient ztunnel) do automatic mutual TLS: each workload gets an X.509 identity (SPIFFE, tied to its ServiceAccount) from the mesh CA, both peers authenticate, traffic is encrypted, and you can write authorization by identity (Istio `AuthorizationPolicy`). No application code changes; adds proxy resource cost and latency; TCP-level for mTLS, richer L7 features on HTTP/gRPC.
- Istio: `PeerAuthentication` with `mtls.mode: STRICT` (namespace or mesh-wide, in `istio-system`) rejects plaintext. `PERMISSIVE` accepts both (migration mode). Linkerd enables mTLS by default for meshed pods.

Choosing:
- Encrypt everything transparently with minimal ops, including non-HTTP and non-meshed pods: CNI encryption.
- Need workload identity, zero-trust authorization, L7 policy/observability: mesh mTLS (often both).
- Application-level TLS (cert-manager-issued certs) is a third option requiring app changes.

## Prerequisites
Docker, `kind`, `helm` and `cilium` CLI optional (for the optional part). Free disk/RAM for a second cluster. The written answer does not need any tools.

## Task
Part A (optional, if time allows; leave `kind-cks` untouched):
1. Create a kind cluster `cks-cilium` (1 control-plane, 1 worker) with the default CNI disabled.
2. Install Cilium with Helm into `kube-system` with encryption enabled using WireGuard.
3. Verify from the Cilium agent that encryption is active and the nodes are peers.
4. Switch back to context `kind-cks` before continuing.

Part B (required, written): in `~/pod-encryption.md`, write one paragraph (under 200 words) that answers all of the following:
1. Difference between CNI-level encryption and mesh-level mTLS (layer, identity, what is encrypted, app changes).
2. When you would choose each, with one concrete scenario each.
3. What Istio resource enforces strict mTLS and what the migration mode is called.
4. Two limitations of each approach.

Part C (short): Show, using only `kubectl` against `kind-cks`, which CNI is in use and state whether the CNI on `kind-cks` encrypts traffic by default (no, unless configured), naming the Calico feature that could.

## Check your work
- (Part A) `kubectl --context kind-cks-cilium -n kube-system exec ds/cilium -- cilium-dbg encrypt status` reports `Encryption: Wireguard` with peers. If the node kernel lacks WireGuard, the agent pods report an error; note it and move on to Part B.
- `kubectl config current-context` prints `kind-cks` at the end.
- The paragraph correctly places CNI encryption at L3/node level and mesh mTLS at L4/L7 per workload identity, mentions no app changes for either, names `PeerAuthentication` `STRICT` and `PERMISSIVE`.
- Part C shows Calico pods (`calico-node`) in `kube-system` or `calico-system`.

## Answer
[answers/week-04-microservice-vulnerabilities/day-07-pod-to-pod-encryption.md](../../answers/week-04-microservice-vulnerabilities/day-07-pod-to-pod-encryption.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete the optional cluster: `kind delete cluster --name cks-cilium`. Ensure the current context is `kind-cks`.
