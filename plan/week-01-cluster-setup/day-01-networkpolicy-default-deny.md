# Week 1 · Day 1 (Sep 23) — NetworkPolicy: default-deny
**Domain:** Cluster Setup (15%) — network security policies | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Explain NetworkPolicy semantics: namespaced, additive, allow-only, CNI-enforced.
- Prove the cluster's default is "allow all" before any policy exists.
- Write a policy that denies all ingress and all egress for every pod in a namespace.
- Observe that default-deny egress also breaks DNS.

## Theory
- NetworkPolicy is a namespaced object. It only takes effect if the CNI enforces it (Calico, Cilium; not kindnet or Docker Desktop's default). This cluster uses Calico.
- No policy selecting a pod = all traffic to/from that pod is allowed. Once any policy selects a pod for a direction (`Ingress` or `Egress`), only traffic matched by some policy's rules is allowed in that direction.
- Policies are additive and allow-only: there are no deny rules, and the union of all matching policies' rules is permitted.
- `spec.podSelector: {}` selects every pod in the namespace.
- `spec.policyTypes` lists the directions the policy governs. A policy with `policyTypes: [Ingress, Egress]` and no `ingress`/`egress` rules denies all traffic in both directions for the selected pods.
- If `policyTypes` is omitted, `Ingress` is always assumed and `Egress` only if `egress` rules exist. Set it explicitly.
- Default-deny egress blocks DNS (UDP/TCP 53 to CoreDNS) too, so name resolution fails until DNS is explicitly allowed (Day 2).
- Useful commands: `kubectl get netpol -n <ns>`, `kubectl describe netpol <name> -n <ns>`, `kubectl get pod -o wide` (pod IPs), `kubectl explain networkpolicy.spec`.
- `busybox` ships `wget` and `nslookup`, not `curl`. Use `wget -qO- -T 3 http://<ip>` for probes.

## Prerequisites
None (cluster `kind-cks` up, Calico running: `kubectl get pods -n calico-system` or `-n kube-system`).

## Task
1. Create namespace `secure-app`.
2. In `secure-app`, run pod `web` (image `nginx`) and pod `client` (image `busybox`, command `sleep 3600`).
3. Wait until both are Running. From `client`, fetch the nginx welcome page from `web`'s pod IP with a 3 second timeout. It must succeed. Also confirm `client` can resolve `kubernetes.default` with `nslookup`.
4. Create a NetworkPolicy named `default-deny-all` in `secure-app` that selects all pods and denies all ingress and all egress. Save the manifest as `~/default-deny-all.yaml` and apply it.
5. Repeat the fetch from step 3 against `web`'s pod IP: it must now fail (time out). Repeat the `nslookup`: it must also fail.

## Check your work
- Before the policy: `wget` prints the "Welcome to nginx!" HTML; `nslookup` returns the cluster DNS answer.
- `kubectl get netpol -n secure-app` lists `default-deny-all`; `kubectl describe` shows `PodSelector: <none>` (empty = all pods) and policy types `Ingress, Egress` with no allowed rules.
- After the policy: `wget` times out (no HTTP response, `wget: download timed out`); `nslookup` reports timeouts / `no servers could be reached`.
- The pods themselves are still Running.

## Answer
[answers/week-01-cluster-setup/day-01-networkpolicy-default-deny.md](../../answers/week-01-cluster-setup/day-01-networkpolicy-default-deny.md) — Attempt the task first; only then open the answer.
