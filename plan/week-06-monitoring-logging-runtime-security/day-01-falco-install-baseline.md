# Week 6 · Day 1 (Oct 28) — Falco: install and baseline
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Install Falco on the kind cluster with the modern eBPF driver.
- Locate and read Falco's alert stream.
- Trigger a default rule ("Terminal shell in container") and identify the fields in the alert.

## Theory
Falco is a runtime behavioral detection engine. A driver in the node kernel (kernel module, classic eBPF probe, or modern eBPF/CO-RE) captures syscalls; the Falco userspace engine enriches events with container and Kubernetes metadata and evaluates them against rules. Matches are emitted as alerts (stdout, file, syslog, HTTP). Falco detects; it does not block.

- Drivers: `kmod`, `ebpf` (legacy probe), `modern_ebpf` (CO-RE, no compile step, needs kernel >= 5.8 with BTF). On kind, nodes share the Docker host kernel, so a kernel module build is fragile; `modern_ebpf` avoids it. On Docker Desktop (macOS) the host is a LinuxKit VM; if the driver fails to load, read the Falco pod logs before assuming a chart problem.
- Falco runs as a privileged DaemonSet (one pod per node) so it sees all containers on that node.
- Rule file layout inside the pod: `/etc/falco/falco_rules.yaml` (default, maintained), `/etc/falco/rules.d/` (custom), `/etc/falco/falco.yaml` (config: `rules_files`, outputs, `json_output`, `priority`).
- Rule anatomy: `rule`, `desc`, `condition`, `output`, `priority`, `tags`; reusable `macro` and `list` objects.
- Default rule "Terminal shell in container": fires on `execve` of a shell binary in a container with an attached TTY (`proc.tty != 0`). `kubectl exec -it` allocates a TTY; `kubectl exec` without `-t` does not trigger it.
- Helm chart: repo `https://falcosecurity.github.io/charts`, chart `falcosecurity/falco`. Key values: `driver.kind`, `tty` (flush stdout output promptly), `falcosidekick.enabled`, `customRules`.
- Useful: `falco -L` (list rules), `falco -V <file>` (validate rules file), `falco --list` (fields/events).

## Prerequisites
none (Helm 3 and `kind-cks` context available).

## Task
1. Confirm `kubectl config current-context` is `kind-cks`.
2. Add the Falco Helm repo and install release `falco` from chart `falcosecurity/falco` into a new namespace `falco`, using the modern eBPF driver and `tty=true`.
3. Wait until the Falco DaemonSet pods on both nodes (`cks-control-plane`, `cks-worker`) are `Running` and ready. If a pod crashes, find the reason in its logs.
4. Identify the containers in a Falco pod (including any init container) and state which one produces alerts.
5. List the rules Falco loaded (use the Falco binary inside the pod) and count how many there are.
6. Create a pod `victim` in namespace `default` running `nginx`.
7. In one terminal follow the Falco logs of the pod that runs on the same node as `victim` (use `-o wide` to find the node). In another, open an interactive shell in `victim`.
8. Confirm an alert named "Terminal shell in container" appears. Record from the alert: priority, process name, user, container name, and image.
9. Run `kubectl exec victim -- ls /` (no TTY) and note whether an alert appears.

## Check your work
- `kubectl get pods -n falco -o wide` shows one ready Falco pod per node.
- Falco startup log lines mention the `modern_ebpf` driver and the loaded rules files.
- After step 7 a log line with `Notice A shell was spawned in a container with an attached terminal` appears containing `container_name=victim`.
- Step 9 produces no new "Terminal shell" alert.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-01-falco-install-baseline.md](../../answers/week-06-monitoring-logging-runtime-security/day-01-falco-install-baseline.md) — Attempt the task first; only then open the answer.

## Cleanup
Keep Falco installed; Days 2, 3 and 4 use it. Remove the pod: `kubectl delete pod victim --now`.
