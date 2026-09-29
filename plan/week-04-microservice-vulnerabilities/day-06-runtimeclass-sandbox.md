# Week 4 · Day 6 (Oct 17) — Sandboxed containers (gVisor/Kata) via RuntimeClass
**Domain:** Minimize Microservice Vulnerabilities (20%) | **Est. time:** 60–90 min | **Cluster:** kind-cks

## Objectives
- Create a `RuntimeClass` and reference it from a pod.
- Explain what must exist on the node for the RuntimeClass to work.
- Predict and read the failure when the handler is not configured.

## Theory
Standard containers (runc) share the host kernel; a kernel exploit or container escape compromises the node. Sandboxed runtimes add a boundary:
- gVisor (`runsc`): a user-space kernel (Sentry) intercepts syscalls; the app never talks directly to the host kernel. Some syscall compatibility and performance cost.
- Kata Containers: each pod runs in a lightweight VM with its own guest kernel; needs virtualization support (KVM/nested virt).

Kubernetes selects a runtime per pod via `RuntimeClass` (`node.k8s.io/v1`, cluster-scoped):
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```
- `handler` is the name of a runtime configured in the node's CRI (containerd or CRI-O), not a binary name Kubernetes resolves itself.
- Pod: `spec.runtimeClassName: gvisor`. Omitted = the CRI default (runc).
- Optional `scheduling.nodeSelector` (+ tolerations) steers pods to nodes that have the runtime; optional `overhead.podFixed` accounts for sandbox cost in scheduling and quota.
- If the handler is unknown on the node the pod stays `ContainerCreating` with a sandbox creation error such as `no runtime for "runsc" is configured`. If the named RuntimeClass object does not exist, admission rejects the pod.
- Node setup for gVisor with containerd: install `runsc` and `containerd-shim-runsc-v1` into a directory on PATH (e.g. `/usr/local/bin`), register the runtime in `/etc/containerd/config.toml`, restart containerd:
  - config v2 (containerd 1.x): `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` with `runtime_type = "io.containerd.runsc.v1"`
  - config v3 (containerd 2.x): `[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runsc]` with the same `runtime_type`
  - the table key (`runsc`) is what `RuntimeClass.handler` must equal. `gvisor` as the RuntimeClass name and `runsc` as the handler are independent.
- Kata: `runtime_type = "io.containerd.kata.v2"`, handler e.g. `kata`.
- Verify a sandboxed pod: `kubectl exec <pod> -- dmesg` (gVisor prints its own boot messages, not the host's) or compare `uname -r`.

kind/macOS: kind nodes are Docker containers using the host's (LinuxKit VM) kernel; there is no `runsc` installed, and nested virtualization for Kata is generally unavailable. Do the YAML work and observe the expected failure; the reasoning is what the exam tests.

## Prerequisites
None.

## Task
1. Create a cluster-scoped `RuntimeClass` named `gvisor` that maps to handler `runsc`.
2. Create namespace `sandbox`. Create a pod `untrusted` in it (image `nginx:1.27`) that uses `runtimeClassName: gvisor`. (Namespace has no PSA enforcement.)
3. Check the pod status. On `kind-cks` it will not become Running. Find, from `describe` and events, the exact error and identify which layer produced it.
4. In your notes file `~/rc-notes.md`, write down (numbered) what you would install and configure on a worker node so the pod actually starts under gVisor with containerd, including the config table key/`runtime_type`, the binaries needed, and the service restart. Also state how you would prove from inside the pod that it is sandboxed, and what changes for Kata.
5. Write a second RuntimeClass `gvisor-scheduled` (handler `runsc`) that only schedules pods on nodes labelled `sandbox=gvisor` and adds a fixed pod overhead of `cpu: 100m`, `memory: 64Mi`. Do not label any nodes. Confirm with `kubectl get runtimeclass` that both exist.
6. Show which pods across the cluster use a non-default runtime with a single jsonpath/custom-columns command.

## Check your work
- `kubectl get runtimeclass` lists `gvisor` (HANDLER `runsc`) and `gvisor-scheduled`.
- `untrusted` is stuck in `ContainerCreating` with an event mentioning failing to create the pod sandbox / `no runtime for "runsc" is configured`.
- The notes cover: install `runsc` + `containerd-shim-runsc-v1`, add runtime entry to `/etc/containerd/config.toml`, restart containerd, matching handler name, and a verification method.
- Step 6 lists `untrusted` with runtime class `gvisor`.

## Answer
[answers/week-04-microservice-vulnerabilities/day-06-runtimeclass-sandbox.md](../../answers/week-04-microservice-vulnerabilities/day-06-runtimeclass-sandbox.md) — Attempt the task first; only then open the answer.

## Cleanup
Delete pod/namespace `sandbox` and both RuntimeClasses.
