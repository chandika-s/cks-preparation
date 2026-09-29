# Week 2 · Day 4 (Oct 3) — Restrict access to the Kubernetes API — Answers
Task: [plan/week-02-cluster-hardening/day-04-restrict-api-server-access.md](../../plan/week-02-cluster-hardening/day-04-restrict-api-server-access.md)

## Solution
1. `docker exec -it cks-control-plane bash`
2. `cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak`
3. ```
grep -E -- '--(anonymous-auth|profiling|enable-admission-plugins|authorization-mode|insecure-port|token-auth-file)' /etc/kubernetes/manifests/kube-apiserver.yaml
```
Typical kind/kubeadm defaults: `--authorization-mode=Node,RBAC`, `--enable-admission-plugins=NodeRestriction`; `--anonymous-auth` and `--profiling` absent (defaults: true). No insecure port/token file.
4. ```
curl -k https://localhost:6443/version
curl -k https://localhost:6443/api/v1/namespaces
```
Before: `/version` returns version JSON (anonymous allowed via `system:public-info-viewer`); `/api/v1/namespaces` returns 403 for `system:anonymous`.
5. Edit `vi /etc/kubernetes/manifests/kube-apiserver.yaml`; under `spec.containers[0].command` add/adjust:
```yaml
    - --anonymous-auth=false
    - --profiling=false
    - --enable-admission-plugins=NodeRestriction
```
(If the plugin flag exists with other plugins, append `,NodeRestriction`; keep everything else.) Use a single flag per name.
6. Wait about 30–90 s (kubectl will error meanwhile):
```
crictl ps | grep kube-apiserver
kubectl get --raw='/readyz'
kubectl get nodes
```
7. ```
curl -k https://localhost:6443/version
```
8. If crashlooping:
```
crictl ps -a | grep kube-apiserver
crictl logs <container-id>
journalctl -u kubelet | tail -50
```
Typical causes: a typo in a flag (`unknown flag` in the container log) or a YAML error (the pod is not created at all; check the kubelet log), or probe 401s from `--anonymous-auth=false`. Fix by restoring the backup:
```
cp /root/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
```
then re-apply only `--profiling=false` (and `NodeRestriction` if it was missing), leaving anonymous auth as is. Alternative for anonymous: the structured `AuthenticationConfiguration` (file mounted via hostPath, `--authentication-config=<path>`, `anonymous.enabled: true` with `conditions` limited to `/livez`, `/readyz`, `/healthz`; do not also set `--anonymous-auth`). Verify availability in your version before relying on it.

## Expected output
```
ok
NAME                STATUS   ROLES           AGE   VERSION
cks-control-plane   Ready    control-plane   ...
```
When anonymous auth is off and the API is stable:
```json
{"kind":"Status","apiVersion":"v1","status":"Failure","message":"Unauthorized","reason":"Unauthorized","code":401}
```

## Why it works
The kubelet watches `/etc/kubernetes/manifests`; a changed manifest causes the static pod to be recreated with the new flags. `--anonymous-auth=false` removes the `system:anonymous` identity path. NodeRestriction limits kubelet credentials to their own node's objects. `--profiling=false` removes pprof handlers.

## Common mistakes / exam gotchas
- Leaving a backup inside `/etc/kubernetes/manifests/` (it becomes a second static pod); back up to `/root` or `/tmp`.
- YAML indentation errors: the pod silently disappears; check `journalctl -u kubelet` or `crictl ps -a`.
- On kind, changes are inside the node container, not the macOS host; the host `kubectl` reaches the API via a forwarded port, and client-certificate auth in the kubeconfig is unaffected by anonymous-auth.
- Probe 401s with `--anonymous-auth=false` on kubeadm-style manifests (probes send no credentials): an apiserver that keeps restarting is the symptom. Exams generally expect the flag; on kind check for restarts (`crictl ps -a`) and be ready to revert.
- Setting `--enable-admission-plugins` without `NodeRestriction` when it was there before removes it (default plugins stay on).
- Do not try `--insecure-port`; it no longer exists and the apiserver refuses unknown flags.
- Write `--profiling=false`, not `--profiling false`.

## Cleanup
Cluster should be healthy.
```
rm /root/kube-apiserver.yaml.bak
```
