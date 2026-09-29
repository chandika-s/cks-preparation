# Week 3 · Day 3 (Oct 9) — Minimize external access to the network
**Domain:** System Hardening (10%) — Minimize external network access | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Identify which control-plane listeners are exposed on all interfaces versus loopback.
- Restrict access to the kube-apiserver secure port with a host firewall rule.
- Verify etcd and the kubelet expose no unintended endpoints.

## Theory
Restrict what is reachable from outside the node, in addition to NetworkPolicy at the pod layer (Week 1).

- **Well-known ports (control plane):** kube-apiserver 6443, etcd client 2379 / peer 2380 (metrics 2381 on loopback), kubelet 10250, kube-scheduler 10259, kube-controller-manager 10257 (both secure, loopback by default). Worker: kubelet 10250, NodePort range 30000–32767.
- **Binding:** `127.0.0.1:port` is reachable only locally; `0.0.0.0`/`*`/`[::]` on all interfaces. Bind addresses are controlled by flags such as `--bind-address`/`--advertise-address` (apiserver), `--listen-client-urls`/`--listen-peer-urls` (etcd), `--address` / config `address` (kubelet).
- **Kubelet:** the read-only port 10255 must be off (`readOnlyPort: 0`, the default in kubeadm), `authentication.anonymous.enabled: false`, `authorization.mode: Webhook`. Check `/var/lib/kubelet/config.yaml`.
- **etcd** must not be reachable by anything but the apiserver; requires client cert auth (`--client-cert-auth=true`) and is best kept on loopback/control-plane addresses only.
- **Host firewalls:** `iptables -A/-I INPUT -p tcp --dport 6443 -s <cidr> -j ACCEPT` plus a final `DROP`; order matters (first match wins; insert allow rules above the drop). `ufw allow from <cidr> to any port 6443 proto tcp` then `ufw deny 6443`, `ufw enable` (careful to allow SSH first). Rules added with iptables are not persistent without `iptables-save`/`netfilter-persistent`.
- **Cloud equivalents:** security groups / firewall rules, private API endpoint, disable public NodePort exposure.
- Commands: `ss -tulpn`, `iptables -L INPUT -n -v --line-numbers`, `iptables -D INPUT <n>`, `nc -zv <ip> <port>`, `curl -k https://<ip>:6443/healthz`.

Kind caveats: kind nodes are Docker containers on the Docker `kind` network. `kubectl` from macOS reaches the API through a Docker port publish on `127.0.0.1:<random>`, so source addresses seen by the node are the Docker bridge gateway. Pods also connect to the apiserver. Careless INPUT rules break the cluster; keep a rescue command ready (`iptables -F INPUT` from `docker exec`). `ufw` is not installed in kind images; use `iptables`.

## Prerequisites
none (do not leave Day 1 module blacklists relevant here)

## Task
On `cks-control-plane` (`docker exec -it cks-control-plane bash`):

1. Run `ss -tulpn | grep LISTEN`. Produce `/root/binding.txt` listing for each control-plane port (6443, 2379, 2380, 2381, 10250, 10257, 10259) whether it is bound to loopback only or to all/other interfaces.
2. Determine the subnet of the Docker network `kind` (`docker network inspect kind` on your workstation) and the Calico pod CIDR (`kubectl get ippools.crd.projectcalico.org -o yaml` or the Calico manifest). Add iptables rules in the `INPUT` chain so that TCP port 6443 accepts traffic only from loopback, the Docker `kind` subnet and the pod CIDR, and drops all other sources. The cluster and `kubectl --context kind-cks get nodes` must keep working afterwards.
3. Prove that the rule set is effective: from a throwaway container on a different Docker network (`docker run --rm --network bridge curlimages/curl -k -m 5 https://<control-plane-ip>:6443/healthz`) show the request is blocked/times out where allowed sources succeed. Note if Docker networking prevents this test and describe an equivalent check (packet counters with `iptables -L INPUT -n -v`).
4. Confirm etcd's client port 2379 listens only on `127.0.0.1` and the node IP (never `0.0.0.0`), by checking both `ss` and the `--listen-client-urls` flag in `/etc/kubernetes/manifests/etcd.yaml`.
5. Confirm the kubelet read-only port is disabled: 10255 must not be listening and `/var/lib/kubelet/config.yaml` must not enable `readOnlyPort`; also confirm `authentication.anonymous.enabled` is `false`.

## Check your work
- `iptables -L INPUT -n -v --line-numbers` shows ACCEPT rules for the three sources above 6443 followed by a DROP for 6443.
- `kubectl get nodes` and `kubectl get pods -A` still succeed; pods using in-cluster apiserver access (e.g. CoreDNS, calico-node) stay `Running`.
- `ss -tulpn | grep -E ':(2379|10255)'` shows no `0.0.0.0:2379` and nothing on 10255.
- `curl -k https://<node-ip>:10250/pods` without credentials returns `401 Unauthorized`.

## Answer
[answers/week-03-system-hardening/day-03-minimize-network-access.md](../../answers/week-03-system-hardening/day-03-minimize-network-access.md) — Attempt the task first; only then open the answer.

## Cleanup
Remove firewall rules so later days are not affected:
`iptables -F INPUT` on the node, or delete only your rules by line number.
