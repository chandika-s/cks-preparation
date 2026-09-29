# Week 6 · Day 3 (Oct 30) — Threat detection across the stack (conceptual) — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-03-threat-detection-across-stack.md](../../plan/week-06-monitoring-logging-runtime-security/day-03-threat-detection-across-stack.md)

## Solution
### Part A — model answers
1. Suspicious DNS every 60 s: Layer network + workload. Sources: Falco `connect` events (UDP/TCP 53 or outbound IPs from that pod, periodic), CoreDNS logs (`log` plugin: queried name, client pod IP), NetworkPolicy/Calico deny logs if egress is restricted. Signal: identical query name at fixed 60 s interval from one pod IP (beaconing).
2. Secret listing at 3 a.m.: Layer users + data. Source: Kubernetes audit log. Signal: `verb=list`, `objectRef.resource=secrets`, `objectRef.namespace=kube-system`, unusual `sourceIPs`, `requestReceivedTimestamp` out of hours, `user.username`/`impersonatedUser`.
3. New binary in `/usr/bin`, then executed: Layer workload (+ node). Source: Falco (default rules "Drop and execute new binary in container", "Write below binary dir"). Signal: write to `/usr/bin` followed by `execve` of that file. Also image drift detection.
4. Cross-namespace attempts: Layer network. Sources: Calico policy deny logs / flow logs, Falco `connect` from unexpected pod to other namespace's IP. Signal: repeated denied connections from namespace A pod IPs to namespace B.
5. Kubelet config modified: Layer infrastructure. Sources: auditd file watch on `/var/lib/kubelet/config.yaml`, Falco on the host ("Write below etc"-style rules), file integrity monitoring. Signal: write/`rename` to that path by a non-package-manager process.

### Part B — Falco rule
1. Lab:
```
kubectl create ns detect
kubectl run beacon -n detect --image=busybox:1.36 -- sleep 3600
```
2. `workspace/week-06/outbound-rule.yaml`:
```yaml
- rule: Unexpected outbound connection from detect namespace
  desc: Outbound IPv4 connect to a destination outside the allow-listed private ranges
  condition: >
    evt.type = connect and evt.dir = < and container
    and fd.typechar = 4 and fd.ip != "0.0.0.0"
    and k8s.ns.name = detect
    and not fd.snet in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8")
  output: >
    Unexpected outbound connection (pod=%k8s.pod.name ns=%k8s.ns.name proc=%proc.name
    cmd=%proc.cmdline dest=%fd.sip:%fd.sport)
  priority: NOTICE
  tags: [custom, network]
```
3. Load with both rule files. Simplest is a values file `workspace/week-06/custom-rules-values.yaml`:
```yaml
customRules:
  shadow-rule.yaml: |-
    <paste content of shadow-rule.yaml, indented 4 spaces>
  outbound-rule.yaml: |-
    <paste content of outbound-rule.yaml, indented 4 spaces>
```
```
helm upgrade falco falcosecurity/falco -n falco --reuse-values -f workspace/week-06/custom-rules-values.yaml
kubectl rollout restart ds/falco -n falco
kubectl rollout status ds/falco -n falco
```
Alternatively with `--set-file` twice:
```
helm upgrade falco falcosecurity/falco -n falco --reuse-values \
  --set-file 'customRules.shadow-rule\.yaml=workspace/week-06/shadow-rule.yaml' \
  --set-file 'customRules.outbound-rule\.yaml=workspace/week-06/outbound-rule.yaml'
```
Note: `helm upgrade` with `-f customRules` replaces the whole `customRules` map only if you re-specify it; specifying both keys avoids losing the Day 2 rule.
4. Outbound:
```
kubectl exec -n detect beacon -- wget -T 3 -qO- http://1.1.1.1
```
5. Internal:
```
KIP=$(kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}')
kubectl exec -n detect beacon -- wget -T 3 -qO- --no-check-certificate https://$KIP
```
(The `busybox` wget may error on TLS; the `connect` syscall is what matters.)
6. Check:
```
kubectl logs -n falco -l app.kubernetes.io/name=falco -c falco --tail=100 | grep 'Unexpected outbound'
```
7. Explanation to write down: Falco hooks syscalls, so it sees the `connect()` destination IP and port, not the DNS name that was resolved earlier; the name exists only in the DNS query/response payload. CoreDNS query logs (or a DNS-aware network sensor) show the domain; correlate with the Falco IP by pod and time.

## Expected output
```
10:52:10.1: Notice Unexpected outbound connection (pod=beacon ns=detect proc=wget cmd=wget -T 3 -qO- http://1.1.1.1 dest=1.1.1.1:80)
```
No alert for the ClusterIP (in `10.96.0.0/16`, inside `10.0.0.0/8`). DNS lookups go to kube-dns (also `10.x`) so they are excluded.

## Why it works
A `connect` event has two phases; `evt.dir = <` selects the exit, when the destination is known. `fd.snet in (...)` does CIDR matching, negated to make an allow-list. Scoping by `k8s.ns.name` bounds noise.

## Common mistakes / exam gotchas
- Omitting `evt.dir = <`: rule evaluates twice, and address fields may be empty on entry.
- Not excluding `0.0.0.0` / unix sockets: `fd.typechar = 4` handles unix; the `0.0.0.0` guard handles unconnected UDP.
- Trying to match domains in `fd.sip.name`: not reliable/deprecated; use IP ranges.
- Forgetting the Day 2 rule when re-running `helm upgrade` with a new `customRules` map.
- Kubernetes NetworkPolicy does not log denials; use Calico policy logging.
- On Docker Desktop the node network is `172.18.0.0/16`; it is inside `172.16.0.0/12`.

## Cleanup
```
kubectl delete ns detect
```
