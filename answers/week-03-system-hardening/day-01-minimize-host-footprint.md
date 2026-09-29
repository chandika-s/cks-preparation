# Week 3 · Day 1 (Oct 7) — Minimize host OS footprint — Answers
Task: [plan/week-03-system-hardening/day-01-minimize-host-footprint.md](../../plan/week-03-system-hardening/day-01-minimize-host-footprint.md)

## Solution
1. Services
```
docker exec -it cks-control-plane bash
systemctl list-units --type=service --state=running
systemctl list-unit-files --state=enabled
```
A kind node is minimal; expect roughly `containerd`, `kubelet`, `systemd-journald`, `systemd-logind`/`dbus` (varies), possibly `ssh`. Record judgement:
```
cat > /root/services.txt <<'EOF'
containerd needed container runtime
kubelet needed node agent
systemd-journald needed logging
ssh not-needed kind uses docker exec; sshd widens remote attack surface
systemd-logind not-needed no interactive logins needed
EOF
```
On a real host you would disable an unneeded service with:
```
systemctl disable --now <svc>
systemctl mask <svc>
```
(Do not stop containerd or kubelet.)

2. Kernel module
```
lsmod | sort -k3 -n | head
lsmod | awk '$3==0 {print $1}'
rmmod <module>
```
Pick a module with Used by = 0 that is not networking/CNI/storage related (avoid `ip_tables`, `nf_*`, `vxlan`, `overlay`, `br_netfilter`, `veth`, `ipip`, and anything Calico or containerd uses). On the shared LinuxKit VM, `rmmod` may fail with `Operation not permitted`, `Module ... is in use`, or `ERROR: Module ... not found`; record the error. This is expected on kind/macOS.

3. Blacklist
```
cat > /etc/modprobe.d/cks-blacklist.conf <<'EOF'
blacklist <module>
install <module> /bin/false
blacklist dccp
install dccp /bin/false
blacklist sctp
install sctp /bin/false
EOF
modprobe -n -v dccp
```

4. Listening ports
```
ss -tulpn
ss -tulpn | awk 'NR==1 || /0.0.0.0|\[::\]|\*/'
```
```
cat > /root/ports.txt <<'EOF'
10250 kubelet API (all interfaces, needs authn/authz)
6443 kube-apiserver
2379 etcd client (127.0.0.1 and node IP)
2380 etcd peer (node IP)
2381 etcd metrics (127.0.0.1)
10257 kube-controller-manager (127.0.0.1)
10259 kube-scheduler (127.0.0.1)
10248 kubelet healthz (127.0.0.1)
10249 kube-proxy metrics (127.0.0.1)
10256 kube-proxy healthz
127.0.0.11:<port> Docker embedded DNS
<containerd> 127.0.0.1 containerd CRI/metrics (ephemeral or fixed port)
EOF
```
5. `exit`, then `docker exec -it cks-worker bash` and rerun `ss -tulpn`: no 6443, 2379/2380/2381, 10257, 10259.

## Expected output
```
# ss -tulpn (abbreviated, control-plane)
tcp LISTEN 0 4096 127.0.0.1:2379   0.0.0.0:* users:(("etcd",...))
tcp LISTEN 0 4096 127.0.0.1:10259  0.0.0.0:* users:(("kube-scheduler",...))
tcp LISTEN 0 4096 *:6443           *:*       users:(("kube-apiserver",...))
tcp LISTEN 0 4096 *:10250          *:*       users:(("kubelet",...))
# modprobe -n -v dccp
install /bin/false
```

## Why it works
Fewer running components and loadable modules mean fewer exploitable code paths and fewer network entry points. `blacklist` blocks alias-based auto-loading; `install <mod> /bin/false` intercepts explicit `modprobe`, which `blacklist` alone does not.

## Common mistakes / exam gotchas
- `blacklist` alone does not stop `modprobe dccp`; add the `install ... /bin/false` line.
- `rmmod` fails while the module is in use; check dependents via `lsmod` "Used by".
- Stopping a service without `disable`/`mask` leaves it to come back at boot or by socket/dependency activation.
- Do not disable containerd/kubelet or CNI-related modules on a live node.
- Config files in `/etc/modprobe.d/` must end in `.conf`.
- Kind nodes share the Docker VM kernel: module changes there are not a faithful exam simulation. On the exam they act on a real VM.

## Cleanup
```
rm -f /etc/modprobe.d/cks-blacklist.conf /root/services.txt /root/ports.txt
```
