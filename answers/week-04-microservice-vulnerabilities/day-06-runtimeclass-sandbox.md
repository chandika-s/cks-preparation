# Week 4 · Day 6 (Oct 17) — Sandboxed containers (gVisor/Kata) via RuntimeClass — Answers
Task: [day-06-runtimeclass-sandbox](../../plan/week-04-microservice-vulnerabilities/day-06-runtimeclass-sandbox.md)

## Solution
1. `rc.yaml`:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```
```
kubectl apply -f rc.yaml
```
2. Pod:
```
kubectl create ns sandbox
kubectl run untrusted -n sandbox --image=nginx:1.27 --dry-run=client -o yaml > untrusted.yaml
```
Add under `spec:` `runtimeClassName: gvisor`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: untrusted
  namespace: sandbox
spec:
  runtimeClassName: gvisor
  containers:
  - name: untrusted
    image: nginx:1.27
```
```
kubectl apply -f untrusted.yaml
```
3. Diagnose:
```
kubectl get pod untrusted -n sandbox
kubectl describe pod untrusted -n sandbox | tail -15
```
4. Notes for `~/rc-notes.md` (model answer):
   1. Download `runsc` and `containerd-shim-runsc-v1` (gVisor release), `chmod +x`, place in `/usr/local/bin` on every node that should run sandboxed pods.
   2. Register the runtime in `/etc/containerd/config.toml`:
      ```
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
        runtime_type = "io.containerd.runsc.v1"
      ```
      (containerd 2.x / config version 3: table `[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runsc]`.)
   3. `systemctl restart containerd` (and kubelet if needed); check `crictl info` lists the `runsc` runtime.
   4. The table key `runsc` must equal `RuntimeClass.handler`.
   5. Optionally label the nodes and set `scheduling.nodeSelector` on the RuntimeClass.
   6. Verify: `kubectl exec untrusted -n sandbox -- dmesg` shows gVisor's synthetic boot log (e.g. "Starting gVisor..."), and `uname -r` differs from the node kernel.
   7. Kata: install Kata, `runtime_type = "io.containerd.kata.v2"`, handler `kata` (or `kata-qemu`); nodes need hardware virtualization; each pod gets a lightweight VM and guest kernel.
5. `rc-sched.yaml`:
```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor-scheduled
handler: runsc
overhead:
  podFixed:
    cpu: 100m
    memory: 64Mi
scheduling:
  nodeSelector:
    sandbox: gvisor
```
```
kubectl apply -f rc-sched.yaml
kubectl get runtimeclass
```
6.
```
kubectl get pods -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,RUNTIME:.spec.runtimeClassName | grep -v '<none>'
```

## Expected output
```
NAME               HANDLER   AGE
gvisor             runsc     10s
gvisor-scheduled   runsc     5s
```
`untrusted`: `ContainerCreating`, event like:
```
Warning  FailedCreatePodSandBox  ...  Failed to create pod sandbox: rpc error: code = Unknown desc = failed to get sandbox runtime: no runtime for "runsc" is configured
```
The error originates in the CRI runtime (containerd) on the node, not the API server or scheduler: the pod was admitted and scheduled fine.

## Why it works
The kubelet passes `runtimeClassName`'s handler to the CRI when creating the sandbox; containerd looks the handler up in its runtimes table and launches the matching shim. Missing table entry = sandbox creation failure. `overhead` is added to the pod's resource requests by the RuntimeClass admission controller, and `nodeSelector` is merged into the pod's selector.

## Common mistakes / exam gotchas
- Confusing the RuntimeClass name (`gvisor`) with the handler (`runsc`); pods reference the name.
- Referencing a RuntimeClass that does not exist: pod rejected at admission (`RuntimeClass "x" not found`).
- Setting `runtimeClassName` on a Deployment's top level instead of `spec.template.spec`.
- Editing the containerd config but forgetting to restart containerd, or putting it under the wrong plugin table for the config version.
- `RuntimeClass` is cluster-scoped: no `-n`.
- gVisor does not support every syscall/feature; hostPath/privileged pods are poor fits.
- Sandboxes are a defence against kernel attacks; they are not a substitute for NetworkPolicy, PSA or RBAC.

## Cleanup
```
kubectl delete ns sandbox
kubectl delete runtimeclass gvisor gvisor-scheduled
rm -f rc.yaml rc-sched.yaml untrusted.yaml
```
