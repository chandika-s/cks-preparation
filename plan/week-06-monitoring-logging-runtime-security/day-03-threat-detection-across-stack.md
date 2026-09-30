# Week 6 · Day 3 (Oct 30) — Threat detection across the stack (conceptual)
**Domain:** Monitoring, Logging and Runtime Security (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Map each threat scenario to the layer and log source that would surface it.
- Write a Falco condition that detects outbound connections to non-allow-listed IP ranges.
- Verify it against a real pod.

## Theory
Detection sources by layer:

| Layer | Sources |
|---|---|
| Infrastructure (nodes) | auditd, Falco on the host, kubelet/containerd logs, cloud provider logs |
| Applications | application logs, ingress/WAF logs, admission denials |
| Network | NetworkPolicy deny logs (Calico log action / flow logs), CoreDNS query logs, Falco `connect` events, service mesh telemetry |
| Data | Secret/ConfigMap access in audit logs, PV mounts, unusual read volume, etcd access |
| Users | Kubernetes audit logs (who/what/when/from where), RBAC changes, failed auth (401/403), impersonation |
| Workloads | Falco runtime events (shells, file tampering, unexpected processes), image drift versus baseline, new privileged pods |

Notes:
- A single event often shows in several sources; correlate by pod, node, time, service account.
- Falco sees syscalls, not DNS payloads. It sees the `connect()` destination IP/port. Domain names come from CoreDNS logs (`log` plugin in the Corefile) or a network sensor. To alert on a suspicious domain, either correlate the resolved IP or use CoreDNS logs.
- Falco network fields: `fd.sip`, `fd.sport`, `fd.snet` (CIDR match, server side), `fd.cip`, `fd.l4proto`, `fd.typechar` (`4` = IPv4, `6` = IPv6). Match outbound with `evt.type = connect and evt.dir = <`.
- Allow-list style: `not fd.snet in ("10.0.0.0/8", ...)` flags everything else. Add namespace or image scoping to control noise.
- Calico can log denies with a `Log` action rule in a `GlobalNetworkPolicy`; plain Kubernetes NetworkPolicy does not log.

## Prerequisites
Day 1–2: Falco installed and rules delivered through the Helm release (`customRules`).

## Exam-style question
Context: Falco runs as release `falco` with the Day 2 rule loaded. Task: (A) in `workspace/week-06/day-03-sources.md`, name the layer, log source and one detection signal for each of five given threat scenarios; (B) in namespace `detect`, pod `beacon` (`busybox:1.36`, `sleep 3600`) must trigger a Falco rule `Unexpected outbound connection from detect namespace` (priority `NOTICE`, rule file `workspace/week-06/outbound-rule.yaml`) only for outbound IPv4 connections to destinations outside `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` and `127.0.0.0/8`. Requirements: keep the Day 2 rule active; the output must include pod, process, command line, destination IP and port; a connection to `1.1.1.1:80` must alert and one to the `kubernetes` service ClusterIP must not.

_Real exam gives only this; the steps under Task are guided practice._

## Task
Part A — analysis. Write your answers in `workspace/week-06/day-03-sources.md`. For each scenario name the layer(s), the log source(s), and one concrete signal to look for:
1. A pod makes DNS requests to a suspicious external domain every 60 seconds.
2. A user lists all Secrets in `kube-system` at 3 a.m. from an unusual IP.
3. A container writes a new binary to `/usr/bin` and executes it.
4. Traffic between namespaces that should be isolated is being attempted.
5. A node's kubelet config file was modified.

Part B — Falco rule.
1. Create namespace `detect` and a pod `beacon` running `busybox:1.36` with command `sleep 3600`.
2. Write `workspace/week-06/outbound-rule.yaml` with a rule `Unexpected outbound connection from detect namespace`:
   - Fires on outbound IPv4 `connect` events from containers in namespace `detect`.
   - Excludes destinations in private/allow-listed ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`.
   - Priority `NOTICE`; output includes pod name, process, command line, destination IP and port.
3. Load it into Falco via the Helm release, keeping the Day 2 rule and earlier values, and restart Falco.
4. From `beacon`, attempt a connection to `1.1.1.1` on port 80 (a short timeout is fine; the connection need not succeed).
5. From `beacon`, attempt a connection to the ClusterIP of the `kubernetes` service.
6. Confirm the alert fires for step 4 and not for step 5.
7. In `day-03-sources.md`, explain in two sentences why this rule cannot see the destination domain name and what source would.

## Check your work
- `day-03-sources.md` covers all 5 scenarios with at least two sources for scenario 1 (Falco network rule and NetworkPolicy/CoreDNS logs).
- Falco logs contain `Notice ... pod=beacon ... 1.1.1.1:80` and none for the kubernetes service IP.
- `helm get values falco -n falco` still contains both custom rule files.

## Answer
[answers/week-06-monitoring-logging-runtime-security/day-03-threat-detection-across-stack.md](../../answers/week-06-monitoring-logging-runtime-security/day-03-threat-detection-across-stack.md) — Attempt the task first; only then open the answer.

## Cleanup
`kubectl delete ns detect`. Leave the rule loaded or remove it from the Helm values; it is scoped to `detect`.
