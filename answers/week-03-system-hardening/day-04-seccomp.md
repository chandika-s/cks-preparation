# Week 3 · Day 4 (Oct 10) — seccomp — Answers
Task: [plan/week-03-system-hardening/day-04-seccomp.md](../../plan/week-03-system-hardening/day-04-seccomp.md)

## Solution
1. RuntimeDefault pod
```
kubectl create ns seccomp-lab
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: default-seccomp
  namespace: seccomp-lab
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx
    command: ["sleep","3600"]
EOF
kubectl -n seccomp-lab exec default-seccomp -- grep Seccomp /proc/1/status
```
2. Profile on the worker
```
docker exec -it cks-worker bash
mkdir -p /var/lib/kubelet/seccomp/profiles
cat > /var/lib/kubelet/seccomp/profiles/deny-mkdir.json <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["unshare", "mkdir", "mkdirat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
exit
```
3. Custom profile pods
```
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-seccomp
  namespace: seccomp-lab
spec:
  nodeName: cks-worker
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/deny-mkdir.json
  containers:
  - name: busybox
    image: busybox
    command: ["sleep","3600"]
EOF
```
4. Test
```
kubectl -n seccomp-lab exec custom-seccomp -- mkdir /tmp/x
kubectl -n seccomp-lab exec custom-seccomp -- grep Seccomp /proc/1/status
kubectl -n seccomp-lab exec default-seccomp -- mkdir /tmp/x && echo ok
```
5. Comparison pods
```
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unconfined
  namespace: seccomp-lab
spec:
  securityContext:
    seccompProfile:
      type: Unconfined
  containers:
  - name: nginx
    image: nginx
    command: ["sleep","3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: custom-nginx
  namespace: seccomp-lab
spec:
  nodeName: cks-worker
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/deny-mkdir.json
  containers:
  - name: nginx
    image: nginx
    command: ["sleep","3600"]
EOF
for p in default-seccomp unconfined custom-nginx; do echo $p; kubectl -n seccomp-lab exec $p -- unshare -U true; echo "rc=$?"; done
```
Expect: `custom-nginx` fails with `unshare: unshare failed: Operation not permitted` (our EPERM). `default-seccomp` also fails with EPERM (RuntimeDefault denies `unshare` without CAP_SYS_ADMIN). `unconfined` succeeds (rc=0) if the Docker VM kernel allows unprivileged user namespaces; if not, it still fails but from the kernel, not seccomp (check `Seccomp: 0`). The reliable `RuntimeDefault` vs custom contrast is `mkdir`.

6. Missing profile
```
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bad-profile
  namespace: seccomp-lab
spec:
  nodeName: cks-worker
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/missing.json
  containers:
  - name: busybox
    image: busybox
    command: ["sleep","3600"]
EOF
kubectl -n seccomp-lab get pod bad-profile
kubectl -n seccomp-lab describe pod bad-profile | tail
```

## Expected output
```
Seccomp:	2
mkdir: can't create directory '/tmp/x': Operation not permitted
command terminated with exit code 1
bad-profile   0/1   CreateContainerError
Error: cannot load seccomp profile ".../seccomp/profiles/missing.json": ... no such file or directory
```
`Seccomp: 0` in `unconfined`.

## Why it works
The kubelet passes the profile path to containerd, which compiles it into a BPF filter installed by runc on the container process (`Seccomp: 2`). Matching syscalls return `EPERM` before reaching the kernel implementation. Both `mkdir` and `mkdirat` are listed because `mkdir` maps to different syscalls by architecture (arm64, i.e. Apple Silicon, has only `mkdirat`).

## Common mistakes / exam gotchas
- `localhostProfile` is relative to `/var/lib/kubelet/seccomp/`; do not put the absolute path.
- The file must exist on every node the pod may land on; use `nodeName`/`nodeSelector`.
- `seccompProfile` goes under `securityContext`, not annotations (annotation form is obsolete).
- Wrong indentation: `type` and `localhostProfile` are children of `seccompProfile`.
- `localhostProfile` is only valid with `type: Localhost`.
- The pod securityContext applies to all containers; container-level overrides.
- Exam variant: profile is provided under `/var/lib/kubelet/seccomp/...` on a specific node; you must schedule to that node and reference it; sometimes the fix is also to correct the JSON.

## Cleanup
```
kubectl delete ns seccomp-lab
docker exec cks-worker rm -rf /var/lib/kubelet/seccomp/profiles
```
