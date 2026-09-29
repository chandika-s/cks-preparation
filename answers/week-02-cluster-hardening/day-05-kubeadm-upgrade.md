# Week 2 · Day 5 (Oct 4) — Upgrade Kubernetes with kubeadm — Answers
Task: [plan/week-02-cluster-hardening/day-05-kubeadm-upgrade.md](../../plan/week-02-cluster-hardening/day-05-kubeadm-upgrade.md)

## Solution
1. ```
kubectl get nodes -o wide
kubectl version
```
2. ```
docker exec -it cks-control-plane bash
kubeadm version -o short
kubeadm upgrade plan
```
On kind this reads the `kubeadm-config` ConfigMap and shows current versions; it may warn that it cannot fetch the latest version from the internet. You can pass a target: `kubeadm upgrade plan v1.35.<patch>`.
3. ```
kubeadm upgrade apply v1.35.<patch> --dry-run
```
Dry run performs preflight and prints what would change without writing. Honest limitation: a real apply on kind needs the new kube-apiserver/controller-manager/scheduler/etcd/kube-proxy images and a matching kubeadm binary inside the node; a stock kind node lacks these, so do not force it. If it works in your setup, follow the real sequence below.
4. ```
kubectl drain cks-worker --ignore-daemonsets --delete-emptydir-data
kubectl get nodes
kubectl get pods -A -o wide | grep cks-worker
```
5. Runbook (real 2-node cluster, v1.34.x -> v1.35.y, Debian/Ubuntu):

Control plane node:
```
sed -i 's/v1.34/v1.35/' /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-cache madison kubeadm
apt-mark unhold kubeadm
apt-get install -y kubeadm='1.35.y-*'
apt-mark hold kubeadm
kubeadm version
kubeadm upgrade plan
kubeadm upgrade apply v1.35.y
kubectl drain <cp-node> --ignore-daemonsets
apt-mark unhold kubelet kubectl
apt-get install -y kubelet='1.35.y-*' kubectl='1.35.y-*'
apt-mark hold kubelet kubectl
systemctl daemon-reload
systemctl restart kubelet
kubectl uncordon <cp-node>
```
Worker node:
```
kubectl drain <worker> --ignore-daemonsets
```
(from control plane), then on the worker:
```
sed -i 's/v1.34/v1.35/' /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-mark unhold kubeadm && apt-get install -y kubeadm='1.35.y-*' && apt-mark hold kubeadm
kubeadm upgrade node
apt-mark unhold kubelet kubectl && apt-get install -y kubelet='1.35.y-*' kubectl='1.35.y-*' && apt-mark hold kubelet kubectl
systemctl daemon-reload
systemctl restart kubelet
```
then from the control plane: `kubectl uncordon <worker>`.
6. `kubectl uncordon cks-worker`
7. `kubectl get nodes -o wide`

Kind-native equivalent of "upgrading": recreate with a newer image, e.g. `kind create cluster --name cks --image kindest/node:v1.35.x --config kind-cks.yaml` (destroys existing state).

## Expected output
Drain:
```
node/cks-worker cordoned
evicting pod ...
node/cks-worker drained
```
Nodes after drain: `Ready,SchedulingDisabled`; after uncordon `Ready`. A real `kubeadm upgrade apply` ends with `[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.35.y".` and `upgrade node` prints that the configuration for this node was successfully updated.

## Why it works
`apply` rewrites the static pod manifests for control plane components and updates kube-proxy/CoreDNS and cluster ConfigMaps; `upgrade node` updates the kubelet config (and static pods on additional control planes). Upgrading the kubelet package plus a restart changes the reported node version. Draining moves workloads off first to avoid disruption.

## Common mistakes / exam gotchas
- Skipping a minor version (v1.33 -> v1.35).
- Upgrading `kubelet` before the control plane, or forgetting `systemctl daemon-reload && systemctl restart kubelet`.
- Using `kubeadm upgrade apply` on a worker; workers use `kubeadm upgrade node`.
- Forgetting `apt-mark unhold` (install fails) or to update the repo minor.
- `kubectl drain` failing without `--ignore-daemonsets`; also stuck on PDBs or local storage (`--delete-emptydir-data`).
- Forgetting to `uncordon`.
- Version string format: `1.35.y-1.1` vs wildcard `1.35.y-*`; use `apt-cache madison` to get it right.
- Drain and uncordon run from the control plane (kubectl); package steps run on the target node over ssh.

## Cleanup
```
kubectl uncordon cks-worker
kubectl get nodes
```
