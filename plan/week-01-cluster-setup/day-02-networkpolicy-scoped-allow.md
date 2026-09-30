# Week 1 · Day 2 (Sep 24) — NetworkPolicy: scoped allow rules
**Domain:** Cluster Setup (15%) — network security policies | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Layer narrow allow policies on top of a default-deny baseline.
- Combine `podSelector`, `namespaceSelector` and `ports` correctly, including the AND vs OR distinction.
- Allow DNS egress to CoreDNS in `kube-system`.
- Verify allowed and blocked flows with timeouts.

## Theory
- Rules are additive. With default-deny in place, each legitimate flow needs an explicit allow in both directions: an egress rule for the source pod and an ingress rule for the destination pod (when both directions are governed by policies).
- `from`/`to` peer types: `podSelector`, `namespaceSelector`, `ipBlock` (`cidr`, optional `except`).
- Within a single `from`/`to` list element, `namespaceSelector` + `podSelector` are ANDed (pods matching, in namespaces matching). As separate list elements they are ORed. Indentation (`- podSelector` vs `  podSelector` under the same dash) decides this.
- A `podSelector` alone in a rule refers to pods in the policy's own namespace.
- Namespaces are selected by labels. Since v1.21 every namespace has `kubernetes.io/metadata.name=<name>`.
- `ports` entries take `protocol` (default TCP) and `port` (number or named). Omit `ports` = all ports.
- DNS: pods query CoreDNS via the `kube-dns` Service on port 53 UDP (and TCP for large responses). CoreDNS pods carry label `k8s-app=kube-dns` in `kube-system`. Policies apply after Service DNAT, so select the CoreDNS pods, not the Service IP.
- Useful commands: `kubectl get pods -n kube-system --show-labels`, `kubectl get ns --show-labels`, `kubectl describe netpol -n <ns>`.

## Prerequisites
Day 1 state: namespace `secure-app` with pods `web` (nginx) and `client` (busybox, `sleep 3600`), and NetworkPolicy `default-deny-all` applied. If missing, recreate them first.

## Exam-style question
Context: namespace `secure-app` contains pods `web` (nginx) and `client` (busybox), and NetworkPolicy `default-deny-all` is already applied. Task: expose `web` as a ClusterIP Service `web` on port 80, then allow only `client` to reach `web` on TCP/80, using policies named `allow-client-to-web`, `allow-client-egress-web` and `allow-dns-egress`. All pods in the namespace must still be able to resolve names through CoreDNS in `kube-system` on port 53 (UDP and TCP). Requirements: do not modify or delete `default-deny-all`, save the manifests under `~/netpol/`, and ensure every other flow (other pods, other ports, other destinations) stays blocked.

_Real exam gives only this; the steps under Task are guided practice._

## Task
1. Expose pod `web` as a ClusterIP Service `web` on port 80 in `secure-app`.
2. Determine the labels on `web`, `client`, and the CoreDNS pods, and the label on the `kube-system` namespace that identifies it by name.
3. Create NetworkPolicy `allow-client-to-web` in `secure-app`: pods labelled as `web` accept ingress only from the `client` pod, only on TCP/80.
4. Create NetworkPolicy `allow-client-egress-web` in `secure-app`: the `client` pod may send egress only to the `web` pod on TCP/80.
5. Create NetworkPolicy `allow-dns-egress` in `secure-app`: all pods in the namespace may send egress to the CoreDNS pods in `kube-system` on port 53, both UDP and TCP. The rule must select by namespace AND pod label in one peer.
6. Do not modify or delete `default-deny-all`. Save the manifests under `~/netpol/`.
7. Verify from `client` (use 3 second timeouts): `http://web` on port 80 works; `http://web:8080` fails by timing out; `nslookup web` resolves; a request to any other destination (e.g. `http://example.com`) does not succeed.

## Check your work
- `kubectl get netpol -n secure-app` shows four policies: `default-deny-all`, `allow-client-to-web`, `allow-client-egress-web`, `allow-dns-egress`.
- `wget -qO- -T 3 http://web` prints the nginx welcome page.
- `wget -T 3 http://web:8080` times out (a timeout, not "connection refused", proves the policy drops it).
- `nslookup web` returns the Service ClusterIP.
- A pod other than `client` (e.g. a temporary `kubectl run tmp --image=busybox -n secure-app -- sleep 600`) cannot reach `web` on port 80.
- `kubectl describe netpol allow-dns-egress -n secure-app` shows a single peer with both `NamespaceSelector` and `PodSelector`.

## Answer
[answers/week-01-cluster-setup/day-02-networkpolicy-scoped-allow.md](../../answers/week-01-cluster-setup/day-02-networkpolicy-scoped-allow.md) — Attempt the task first; only then open the answer.
