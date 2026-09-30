# Week 3 · Day 1 (Oct 7) — Minimize host OS footprint
**Domain:** System Hardening (10%) — Minimize host OS footprint | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Enumerate running services and identify ones a Kubernetes node does not need.
- Unload an unused kernel module and blacklist it persistently.
- Map every listening socket on a node to a process and purpose.

## Theory
Every package, daemon, open port and kernel module is attack surface. Hardening the host OS means removing or disabling what a Kubernetes node does not need.

- **Services:** a node needs only the container runtime (containerd), kubelet, and basic OS plumbing (systemd, journald, optionally sshd). Disable/mask everything else (`systemctl disable --now <svc>`, `systemctl mask <svc>`). Typical candidates on general-purpose hosts: `snapd`, `cups`, `avahi-daemon`, `bluetooth`, `rpcbind`, `postfix`, `vsftpd`, `apache2`/`nginx` installed on the host.
- **Packages:** remove compilers, debuggers, package managers and network tools not needed in production (`apt purge`, `apt autoremove`). Prefer minimal, container-optimised host OSes.
- **Kernel modules:** unused modules (rare filesystems/protocols such as `dccp`, `sctp`, `rds`, `tipc`, `cramfs`) widen the kernel attack surface. `lsmod` lists loaded modules (column "Used by" is the refcount; 0 means unused). `rmmod <mod>` unloads (fails if in use); `modprobe -r <mod>` also unloads dependents. To prevent loading persistently, add to `/etc/modprobe.d/<name>.conf`: `blacklist <mod>` (stops alias auto-load) and `install <mod> /bin/false` (stops explicit `modprobe`).
- **Listening ports:** `ss -tulpn` (`-t` TCP, `-u` UDP, `-l` listening, `-p` process, `-n` numeric). Also `lsof -i -P -n`. Every listener must be justified.
- **Useful:** `systemctl list-units --type=service --state=running`, `systemctl list-unit-files --state=enabled`, `dpkg -l` / `apt list --installed`, `ps aux`.

Kind caveat: nodes are Docker containers running systemd; they share the kernel of Docker Desktop's Linux VM. Kernel-module changes affect (or are refused by) that shared kernel, and `/lib/modules` may be absent in the node image.

## Prerequisites
none

## Exam-style question
Context: node `cks-control-plane` (cluster `kind-cks`) is a general-purpose host that may run services, kernel modules and listeners a Kubernetes node does not need. Task: review the node's running services and listening sockets, disable the attack surface that is not needed, and prevent the `dccp` and `sctp` kernel modules from ever being loaded. Requirements: save your service assessment to `/root/services.txt` and a port-to-process mapping of every listener to `/root/ports.txt` on the node; make the module restriction persistent under `/etc/modprobe.d/`; do not stop containerd, kubelet or anything the cluster depends on, and the cluster must stay healthy.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Work on node `cks-control-plane` (`docker exec -it cks-control-plane bash`). Context `kind-cks`.

1. List all running systemd services. Identify at least 3 that are not required for a Kubernetes node to function (or, if the node is already minimal, state which ones are required and why: containerd, kubelet, systemd-journald, etc.). Record your reasoning in `/root/services.txt` on the node, one line per service in the form `<service> <needed|not-needed> <reason>`.
2. Run `lsmod`. Choose a loaded module with a "Used by" count of 0 that a Kubernetes node does not need and unload it with `rmmod`. If unloading is refused (shared Docker VM kernel), record the error.
3. Create `/etc/modprobe.d/cks-blacklist.conf` that blacklists the module chosen in step 2 and additionally blacklists `dccp` and `sctp` so that `modprobe` cannot load them.
4. List all listening TCP/UDP sockets with owning process. Write `/root/ports.txt` mapping each port to process and purpose (e.g. `10250 kubelet API`, `6443 kube-apiserver`, `2379 etcd client`). Flag any port that is unexpected or bound to `0.0.0.0`/`::` that need not be.
5. Repeat step 4 on `cks-worker` and note which control-plane-only ports are absent there.

## Check your work
- `/root/services.txt` and `/root/ports.txt` exist and cover every running service and every listener.
- `lsmod | grep <module>` shows nothing (or you have the recorded refusal error).
- `cat /etc/modprobe.d/cks-blacklist.conf` contains a `blacklist` line and an `install <mod> /bin/false` line for each of the three modules.
- `modprobe -n -v dccp` (dry run) prints `install /bin/false` rather than loading a module.
- You can name the process behind every port in `ss -tulpn` output.

## Answer
[answers/week-03-system-hardening/day-01-minimize-host-footprint.md](../../answers/week-03-system-hardening/day-01-minimize-host-footprint.md) — Attempt the task first; only then open the answer.

## Cleanup
Remove `/etc/modprobe.d/cks-blacklist.conf` if you blacklisted a module that anything else on the Docker VM needs. Recreate the cluster if the node breaks.
