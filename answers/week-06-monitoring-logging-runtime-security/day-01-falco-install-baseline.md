# Week 6 · Day 1 (Oct 28) — Falco: install and baseline — Answers
Task: [plan/week-06-monitoring-logging-runtime-security/day-01-falco-install-baseline.md](../../plan/week-06-monitoring-logging-runtime-security/day-01-falco-install-baseline.md)

## Solution
1. Context:
```
kubectl config current-context
```
2. Install:
```
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true
```
3. Wait:
```
kubectl get pods -n falco -o wide -w
kubectl logs -n falco <falco-pod> -c falco
```
4. Containers:
```
kubectl get pod -n falco <falco-pod> -o jsonpath='{.spec.initContainers[*].name}{"\n"}{.spec.containers[*].name}{"\n"}'
```
The `falco` container emits alerts. `falcoctl-artifact-install` (init) and `falcoctl-artifact-follow` (sidecar) manage rule artifacts (recent chart versions).
5. Rules:
```
kubectl exec -n falco <falco-pod> -c falco -- falco -L | head -50
```
Count with `... | grep -c .` (approximate; header lines are included).
6. Victim:
```
kubectl run victim --image=nginx
kubectl get pod victim -o wide
```
7. Two terminals:
```
kubectl logs -n falco <falco-pod-on-that-node> -c falco -f
kubectl exec -it victim -- sh
```
Shortcut to find the right Falco pod: `kubectl get pods -n falco -o wide --field-selector spec.nodeName=<node>`.
8. Read the alert (see below).
9. `kubectl exec victim -- ls /` prints the directory and no shell alert fires (no TTY).

## Expected output
```
NAME          READY   STATUS    NODE
falco-abcde   2/2     Running   cks-control-plane
falco-fghij   2/2     Running   cks-worker
```
Alert (fields abbreviated):
```
10:14:02.123456789: Notice A shell was spawned in a container with an attached terminal (evt_type=execve user=root user_uid=0 ... process=sh ... container_id=... container_name=victim container_image_repository=docker.io/library/nginx ...)
```
Priority `Notice`, process `sh`, user `root`.

## Why it works
The modern eBPF probe is compiled into the Falco binary (CO-RE), so no kernel headers or module build are needed on the kind node. The DaemonSet is privileged and mounts the container runtime socket so Falco can tag events with container and pod names. The default rule matches shell binaries spawned with a TTY inside a container; `-it` supplies one.

## Common mistakes / exam gotchas
- `driver.kind=kmod` or defaults on kind: module build fails; pod crash-loops or sits in Init.
- Forgetting `--create-namespace`.
- Following logs of the Falco pod on the wrong node: the alert only appears on the pod on the node where the victim runs.
- `kubectl exec -- sh` without `-t` does not trigger the rule.
- Reading the wrong container's logs (`-c falco`).
- If `modern_ebpf` cannot load on your Docker Desktop VM (missing BTF), the pod logs say so; the concept still holds, and on the real exam Falco is typically pre-installed as a systemd service on a node (`journalctl -u falco`, or `/var/log/syslog`).

## Cleanup
```
kubectl delete pod victim --now
```
Leave Falco installed for Days 2–4.
