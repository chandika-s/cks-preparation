# Week 3 · Day 3 (Oct 9) — Minimize external access to the network — Answers
Task: [plan/week-03-system-hardening/day-03-minimize-network-access.md](../../plan/week-03-system-hardening/day-03-minimize-network-access.md)

## Solution
1. Binding
```
docker exec -it cks-control-plane bash
ss -tulpn | grep LISTEN
```
Typical kubeadm/kind result, written to `/root/binding.txt`:
```
6443  all interfaces (*)          kube-apiserver
2379  127.0.0.1 and <node-ip>     etcd client
2380  <node-ip>                   etcd peer
2381  127.0.0.1                   etcd metrics
10250 all interfaces (*)          kubelet (authn/authz enforced)
10257 127.0.0.1                   controller-manager
10259 127.0.0.1                   scheduler
```
2. Firewall on 6443
On the workstation:
```
docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}'
kubectl get ippools.crd.projectcalico.org -o jsonpath='{.items[*].spec.cidr}'
```
Assume Docker subnet `172.18.0.0/16` and pod CIDR `192.168.0.0/16` (substitute yours). On the node:
```
iptables -I INPUT 1 -p tcp --dport 6443 -i lo -j ACCEPT
iptables -I INPUT 2 -p tcp --dport 6443 -s 172.18.0.0/16 -j ACCEPT
iptables -I INPUT 3 -p tcp --dport 6443 -s 192.168.0.0/16 -j ACCEPT
iptables -I INPUT 4 -p tcp --dport 6443 -j DROP
iptables -L INPUT -n -v --line-numbers
kubectl --context kind-cks get nodes
```
Inserting at explicit positions puts the ACCEPTs above the DROP and above kube-proxy/kubelet chains that may also jump from INPUT. Also allow `service CIDR` traffic only if it reaches INPUT un-DNATed (normally not: kube-proxy DNATs to the node IP first, so the source is a pod IP or node IP already allowed).

3. Verify
```
docker run --rm --network bridge curlimages/curl -k -m 5 https://<control-plane-ip-on-kind-net>:6443/healthz
```
From the default `bridge` network the address on the `kind` network is typically not routable (Docker isolates networks), so the request times out even before your rule. Then the meaningful evidence is the DROP counter and that a permitted source works:
```
docker run --rm --network kind curlimages/curl -k -m 5 https://cks-control-plane:6443/healthz
iptables -L INPUT -n -v --line-numbers
```
The kind-network test succeeds (`401`/`ok`, since the kind subnet is allowed); to see a drop, temporarily remove the `172.18.0.0/16` ACCEPT and rerun to observe the timeout and the DROP counter increment, then re-add the rule.

4. etcd
```
ss -tulpn | grep 2379
grep -E 'listen-client-urls|listen-peer-urls|client-cert-auth' /etc/kubernetes/manifests/etcd.yaml
```
Expect `--listen-client-urls=https://127.0.0.1:2379,https://<node-ip>:2379`, `--client-cert-auth=true`.

5. Kubelet
```
ss -tulpn | grep 10255
grep -E 'readOnlyPort|anonymous|mode' -A2 /var/lib/kubelet/config.yaml
curl -sk https://localhost:10250/pods
```
Expect no 10255 listener, `anonymous: enabled: false`, `authorization: mode: Webhook`, and `Unauthorized` on the curl. Cert paths for etcd on kind/kubeadm: `/etc/kubernetes/pki/etcd/{ca.crt,server.crt,server.key,peer.crt,peer.key}`.

## Expected output
```
Chain INPUT
num  pkts bytes target  prot opt in  out source          destination
1       .     . ACCEPT  tcp  --  lo  *   0.0.0.0/0       0.0.0.0/0    tcp dpt:6443
2       .     . ACCEPT  tcp  --  *   *   172.18.0.0/16   0.0.0.0/0    tcp dpt:6443
3       .     . ACCEPT  tcp  --  *   *   192.168.0.0/16  0.0.0.0/0    tcp dpt:6443
4       .     . DROP    tcp  --  *   *   0.0.0.0/0       0.0.0.0/0    tcp dpt:6443
```

## Why it works
iptables evaluates INPUT top-down; matching ACCEPTs short-circuit and everything else to 6443 hits the DROP. etcd and kubelet exposure is governed by their bind flags/config and auth, not the firewall alone.

## Common mistakes / exam gotchas
- Appending (`-A`) the ACCEPT after the DROP: it never matches.
- Locking yourself out by dropping 6443 without allowing loopback and pod/node sources: control-plane components (kubelet, controller-manager, scheduler) use the apiserver too.
- `ufw enable` without first allowing SSH (not applicable on kind, where `ufw` is missing).
- Rules are lost on reboot unless persisted (`iptables-save`, `netfilter-persistent`).
- Changing static-pod flags (e.g. etcd `--listen-client-urls`) means editing `/etc/kubernetes/manifests/*.yaml`; the kubelet recreates the pod. Take a backup outside that directory.
- On kind, the "external" path is Docker port publishing, so exact source IPs differ from a real cluster.

## Cleanup
```
iptables -F INPUT
```
(or `iptables -D INPUT 4` and lines 3, 2, 1 in reverse order.)
